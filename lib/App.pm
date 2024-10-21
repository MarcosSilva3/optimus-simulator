package App;
use Dancer2;
use Dancer2::Logger::Console::Colored;
use Dancer2::Plugin::Database;
use Dancer2::Core::Request;

use HTTP::Request::Common;
use Mojo::Base -strict;
use Mojo::File;
use Paws;
use Paws::Net::LWPCaller;
use MIME::Base64;
use LWP::UserAgent;

use JSON::Parse ':all';
use Encode qw(encode_utf8);
use Cwd 'abs_path';
use Data::Dumper;
use File::Copy;
use POSIX qw(strftime ceil);
use Date::Calc qw(Add_Delta_Days Delta_Days Today Monday_of_Week);
use DateTime;
use DateTime::TimeZone;
use Statistics::Descriptive;
use Scalar::Util qw(looks_like_number);
use List::Util qw(min max);
use HTML::TableExtract;
use Geo::WKT::Simple ':parse';  # Only WKT parser functions



use FindBin;
use lib "$FindBin::Bin/../lib";

use Plots;

set 'show_errors'  => 1;
set 'startup_info' => 1;
set 'warnings'     => 1;

# Local project folder: /home/evsro/perl-projects/optimus-simulator


#
# To build the image using Docker
# docker build --tag hom-fr .
#   
# To run locally using docker:
# docker run --env-file my-env.txt --publish 8080:3000 hom-fr:latest

# To stop the container you can check the proccess in Docker:
# docker ps

# And then use
# docker kill 328327389ya

# Cloud 9
# plackup --port 8080 -r ./bin/app.psgi

#-----------------------------------------------------------------------------#
get '/' => sub {
    
    my $scenario = "Optimus";
    my $user_id = session('user_id');
    app->destroy_session;

    session 'scenario' => $scenario;
    redirect "/dashboard";

    template 'index' => { 
        title => 'Optimus',
        scenario => $scenario
    };
};
#-----------------------------------------------------------------------------#
get '/index' => sub {
    my $scenario = "Optimus";
    app->destroy_session;
    
    session 'scenario' => $scenario;
    template 'index' => { 
        title => 'Optimus',
        scenario => $scenario
    };
};
#-----------------------------------------------------------------------------#
get '/healthcheck' => sub {
    return 'Optimus rocks!';
};
#-----------------------------------------------------------------------------#
get '/logout' => sub {
    app->destroy_session;
    session 'scenario' => '';
    redirect "/login";
};
#-----------------------------------------------------------------------------#
get '/dashboard' => sub {
    my $scenario = session('scenario');


    if(length $scenario)
    {
        my $map = &getMapAllFields();
        
        template 'dashboard' => { 
            title => 'Optimus', 
            map => $map
        };
    } else {
        redirect "/index";
    }
};

#-----------------------------------------------------------------------------#
get '/dashboard_data' => sub {
    my $hash;
    my $query = 'select sum("totalPlots") as total_plots, count(distinct("plantingMachine")) as total_planters, count(distinct("droneMachine")) as total_drones, count(distinct("harvestMachine")) as total_combines from fieldsplanting';
    my $sth = database->prepare($query);
    $sth->execute;

    my ($total_plots, $total_planters, $total_drones, $total_combines) = $sth->fetchrow;
    $hash->{'total_plots'} = $total_plots;
    $hash->{'total_planters'} = $total_planters;
    $hash->{'total_drones'} = $total_drones;
    $hash->{'total_combines'} = $total_combines;
    return encode_json($hash);
};

#-----------------------------------------------------------------------------#
sub getPickerGroups
{
    my @pickers = ();
    my $sth = database->prepare('select distinct "harvestMachine" from fieldsplanting');
    $sth->execute();
    my $i = 100;
    while(my $hash = $sth->fetchrow_hashref)
    {
        push @pickers, $hash->{'harvestMachine'};
    }

    $sth->finish;
    return \@pickers;
}

#-----------------------------------------------------------------------------#
sub getMapAllFields
{
    my $str = "";
    my $query = 'select "fieldName", homesite, "subCountry", "subSubCountry", "growingSeason", lat, lon, "totalPlots", "harvestMachine", coordinates from fieldsplanting';
    my $sth = database->prepare($query);
    $sth->execute();

    my @pickers = @{&getPickerGroups};
    my $n_pickers = scalar @pickers;
    debug("Number of pickers: $n_pickers");

    my @colors = ('yellow', 'red', 'purple', 'pink', 'orange', 'blue', 'green', 'blue');

    my $c = 0;
    my %hPickerColor = ();
    for my $picker (@pickers)
    {
        $hPickerColor{$picker} = $colors[$c];
        $c++;
        $c = 0 if $c >= scalar(@colors);
    }

    my $i = 100;
    while(my $hash = $sth->fetchrow_hashref)
    {
        my $field = $hash->{'fieldName'};
        my $homesite = $hash->{'homesite'};
        my $sub_country = $hash->{'subCountry'};
        my $sub_sub_country = $hash->{'subSubCountry'};
        my $season = $hash->{'growingSeason'};
        my $lat = $hash->{'lat'};
        my $lon = $hash->{'lon'};
        my $total_plots = $hash->{'totalPlots'};
        my $picker = $hash->{'harvestMachine'};


        my $color = "red";
        if(exists $hPickerColor{$picker})
        {
            $color = $hPickerColor{$picker};
        } else {
            debug("Picker $picker without color defined.");
        }

        my $wkt = $hash->{'coordinates'};
        $str .= "var contentString$i = '<b>$field - Home Site: </b>$homesite<br><b>Season: </b>$season<br><b>Location: </b>$sub_sub_country<br><b>State: </b>$sub_country<br>";
        $str .= "<b>Picker group: </b>$picker<br>";
        $str .= "<a href=/editfield?lot=$field>Edit field</a>';\n";
        $str .= "var infowindow$i = new google.maps.InfoWindow({\n";
        $str .= "\tcontent: contentString$i\n";
        $str .= "});\n";
    
        $str .= "var myvar$i = new google.maps.Marker({\n";
        $str .= "\t\tposition: {lat: $lat, lng: $lon},\n";
        $str .= "\t\tmap: map,\n";
        $str .= "\t\ticon: 'http://maps.google.com/mapfiles/ms/icons/$color-dot.png',\n";
        $str .= "\t});\n";
        
        $str .= "myvar$i.addListener('click', function() {\n";
        $str .= "\tinfowindow$i.open(map, myvar$i);\n";
        $str .= "});\n";

        my @polygon = ();
        my $map_polygon = "const field_coords$i = [\n";
        if($wkt =~ /^MULTIPOLYGON/)
        {
            @polygon = wkt_parse_multipolygon($wkt);
            my $count = 1;
            for my $row1 (@polygon)
            {
                $map_polygon = "const field_coords\_$i\_$count = [\n";
                for my $row2 (@$row1)
                {
                    for my $coord (@$row2)
                    {
                        my $tmp_lon = $coord->[0];
                        my $tmp_lat = $coord->[1];
                        # print "lat: $tmp_lat, lon: $tmp_lon\n";
                        $map_polygon .= "{ lat: $tmp_lat, lng: $tmp_lon },"
                    }
                }
                $map_polygon .= "];\n";
                $map_polygon .= "const field_polygon\_$i\_$count = new google.maps.Polygon({
                    paths: field_coords\_$i\_$count,
                    strokeColor: \"#FF0000\",
                    strokeOpacity: 0.8,
                    strokeWeight: 2,
                    fillColor: \"#FF0000\",
                    fillOpacity: 0.35,
                });
                field_polygon\_$i\_$count.setMap(map);\n";
                $count++;
            }

        } else {
            @polygon = wkt_parse_polygon($wkt);
            for my $row (@polygon)
            {
                for my $coord (@$row)
                {
                    my $tmp_lon = $coord->[0];
                    my $tmp_lat = $coord->[1];
                    # print "lat: $tmp_lat, lon: $tmp_lon\n";
                    $map_polygon .= "{ lat: $tmp_lat, lng: $tmp_lon },"
                }
            }
            $map_polygon .= "];\n";

            $map_polygon .= "const field_polygon$i = new google.maps.Polygon({
                paths: field_coords$i,
                strokeColor: \"#FF0000\",
                strokeOpacity: 0.8,
                strokeWeight: 2,
                fillColor: \"#FF0000\",
                fillOpacity: 0.35,
            });
            field_polygon$i.setMap(map);\n";
        }

        $str .= $map_polygon;

        $i++;
    }

    $sth->finish;
    return $str;
}
#-----------------------------------------------------------------------------#


1;
