package Plots;

use Exporter qw(import);
our @EXPORT_OK = qw(volume_per_day hybrids_per_day area_per_day lateness_fields lateness_volume);

use strict;
use warnings;

use Amazon::S3::Thin;
use XML::Simple qw(:strict);
use JSON qw(decode_json);
use DBI;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use Date::Calc qw(Add_Delta_Days);
use POSIX qw(ceil);

#-----------------------------------------------------------------------------#
sub trucks_per_week
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $query = "SELECT DISTINCT DATE_PART('week', harv_date) AS weekofyear, SUM(tonrw_harv) FROM homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber') and plantnumber=? GROUP BY weekofyear ORDER BY weekofyear;";
    my $sth = $dbh->prepare($query);
    $sth->execute($plantNumber);

    my $truck_capacity = 23; # tons / truck
    my $x = "x: [";
    my $y = "y: [";
    my $text = "[";

    while(my $line = $sth->fetchrow_arrayref)
    {
        my $week = int($line->[0]);
        my $volume = $line->[1];
        my $trucks = $volume / $truck_capacity;
        $trucks = int($trucks + 0.5);
        $x .= "'$week', ";
        $y .= "$trucks, ";
        my $str = sprintf("%d trucks in week %d", $trucks, $week);
        $text .= "'$str', ";
    }
    $x =~ s/, $/\]/g;
    $y =~ s/, $/\]/g;
    $text =~ s/, $/\],/g;

    my $str = "\n\nvar trucks_per_week = {\n\t$x,\n\t$y,\n\ntype: 'bar',\n\ttext: $text\n};\n";
    $str .= "var data_trucks_per_week = [trucks_per_week];\n";
    $str .= "var layout_trucks_per_week = {\n";
    $str .= "\ttitle: 'Expected # of trucks per week',\n";
    $str .= "showlegend: false,\n";
    $str .= "xaxis: { title: 'Harv.Week' },\n";
    $str .= "yaxis: { title: '# of trucks' },\n";
    $str .= "};\n";
    $str .= "Plotly.plot('trucks_per_week', data_trucks_per_week, layout_trucks_per_week, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub trucks_per_day
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $query = "select distinct harv_date, sum(tonrw_harv) from homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber') and plantnumber=? group by harv_date order by harv_date";
    my $sth = $dbh->prepare($query);
    $sth->execute($plantNumber);

    my $truck_capacity = 23; # tons / truck
    my $x = "x: [";
    my $y = "y: [";
    my $text = "[";

    while(my $line = $sth->fetchrow_arrayref)
    {
        my $date = $line->[0];
        my $volume = $line->[1];
        my $trucks = $volume / $truck_capacity;
        $trucks = int($trucks + 0.5);
        $x .= "'$date', ";
        $y .= "$trucks, ";
        my $str = sprintf("%d trucks in %s", $trucks, $date);
        $text .= "'$str', ";
    }
    $x =~ s/, $/\]/g;
    $y =~ s/, $/\]/g;
    $text =~ s/, $/\],/g;

    my $str = "\n\nvar trucks_per_day = {\n\t$x,\n\t$y,\n\ntype: 'bar',\n\ttext: $text\n};\n";
    $str .= "var data_trucks_per_day = [trucks_per_day];\n";
    $str .= "var layout_trucks_per_day = {\n";
    $str .= "\ttitle: 'Expected # of trucks per day',\n";
    $str .= "showlegend: false,\n";
    $str .= "xaxis: { type: 'date', title: 'Harv.Date' },\n";
    $str .= "yaxis: { title: '# of trucks' },\n";
    $str .= "};\n";
    $str .= "Plotly.plot('trucks_per_day', data_trucks_per_day, layout_trucks_per_day, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub volume_per_day
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $query = "select distinct harv_date, sum(tonrw_harv) from homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber') and plantnumber=? group by harv_date order by harv_date";
    my $sth = $dbh->prepare($query);
    $sth->execute($plantNumber);

    my $x = "x: [";
    my $y = "y: [";
    my $text = "[";

    while(my $line = $sth->fetchrow_arrayref)
    {
        my $date = $line->[0];
        my $volume = $line->[1];
        my $sVolume = sprintf("%.2f", $volume);
        $x .= "'$date', ";
        $y .= "$sVolume, ";
        my $str = sprintf("%.2f tons in %s", $volume, $date);
        $text .= "'$str', ";
    }
    $x =~ s/, $/\]/g;
    $y =~ s/, $/\]/g;
    $text =~ s/, $/\],/g;

    my $str = "var trace1 = {\n\t$x,\n\t$y,\n\ntype: 'bar',\n\ttext: $text\n};\n";
    $str .= "var data = [trace1];\n";
    $str .= "var layout = {\n";
    $str .= "\ttitle: 'Expected volume per day',\n";
    $str .= "showlegend: false,\n";
    $str .= "xaxis: { type: 'date', title: 'Harv.Date' },\n";
    $str .= "yaxis: { title: 'Volume (Ton.RW)' },\n";
    $str .= "};\n";
    $str .= "Plotly.plot('volume_per_day', data, layout, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub volume_per_week
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $query = "SELECT DISTINCT DATE_PART('week', harv_date) AS weekofyear, SUM(tonrw_harv) FROM homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber') and plantnumber=? GROUP BY weekofyear ORDER BY weekofyear;";
    my $sth = $dbh->prepare($query);
    $sth->execute($plantNumber);

    my $x = "x: [";
    my $y = "y: [";
    my $text = "[";

    while(my $line = $sth->fetchrow_arrayref)
    {
        my $week = int($line->[0]);
        my $volume = $line->[1];
        my $sVolume = sprintf("%.2f", $volume);
        $x .= "'$week', ";
        $y .= "$sVolume, ";
        my $str = sprintf("%.2f tons in week %d", $volume, $week);
        $text .= "'$str', ";
    }
    $x =~ s/, $/\]/g;
    $y =~ s/, $/\]/g;
    $text =~ s/, $/\],/g;

    my $str = "var trace1 = {\n\t$x,\n\t$y,\n\ntype: 'bar',\n\ttext: $text\n};\n";
    $str .= "var data = [trace1];\n";
    $str .= "var layout = {\n";
    $str .= "\ttitle: 'Expected volume per week',\n";
    $str .= "showlegend: false,\n";
    $str .= "xaxis: { title: 'Harv.Week' },\n";
    $str .= "yaxis: { title: 'Volume (Ton.RW)' },\n";
    $str .= "};\n";
    $str .= "Plotly.plot('volume_per_week', data, layout, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub area_per_week
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $sth;

    if($plantNumber == 1318 or $plant =~ "SPAIN") {
        my $query = "SELECT lot, DATE_PART('week', twstart), area FROM fieldhom where sitekey='$plantNumber' and region = '$plant'";
        $sth = $dbh->prepare($query);
        $sth->execute();
    } else {
        my $query = "SELECT lot, DATE_PART('week', twstart), area FROM fieldhom where sitekey='$plantNumber' and region not like '\%SPAIN\%'";
        $sth = $dbh->prepare($query);
        $sth->execute();
    }

    my %hFieldsHarvested = %{&get_fields_harvested($dbh, $plant, $plantNumber)};
    my %hArea = ();
    while(my ($tracking_number, $week_number, $area) = $sth->fetchrow)
    {
        next if exists $hFieldsHarvested{$tracking_number};
        $hArea{$week_number} += $area;
    }

    my $x = "x: [";
    my $y = "y: [";
    my $text = "[";

    foreach my $week_number (sort {$a <=> $b} keys %hArea)
    {
        my $area = $hArea{$week_number};
        my $sArea = sprintf("%.2f", $area);
        $x .= "'$week_number', ";
        $y .= "$sArea, ";
        my $str = sprintf("%.2f ha. in week %d", $area, $week_number);
        $text .= "'$str', ";
    }
    $x =~ s/, $/\]/g;
    $y =~ s/, $/\]/g;
    $text =~ s/, $/\],/g;

    my $str = "var trace1_area = {\n\t$x,\n\t$y,\n\ntype: 'bar',\n\ttext: $text\n};\n";
    $str .= "var data_area = [trace1_area];\n";
    $str .= "var layout_area = {\n";
    $str .= "\ttitle: 'Expected area to be harvested',\n";
    $str .= "showlegend: false,\n";
    $str .= "xaxis: { title: 'Harv.Week' },\n";
    $str .= "yaxis: { title: 'Area (ha)' },\n";
    $str .= "};\n";
    $str .= "Plotly.plot('area_per_week', data_area, layout_area, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub volume_per_week_interactive
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $sth;

    if($plantNumber == 1318 or $plant =~ "SPAIN") {
        my $query = "SELECT lot, twstart, DATE_PART('week', twstart), area, tonha FROM fieldhom where sitekey='$plantNumber' and region = '$plant'";
        $sth = $dbh->prepare($query);
        $sth->execute();
    } else {
        my $query = "SELECT lot, twstart, DATE_PART('week', twstart), area, tonha FROM fieldhom where sitekey='$plantNumber' and region not like '\%SPAIN\%'";
        $sth = $dbh->prepare($query);
        $sth->execute();
    }

    my %hFieldsHarvested = %{&get_fields_harvested($dbh, $plant, $plantNumber)};
    my %hVolume = ();
    while(my ($tracking_number, $harvest_window_start, $week_number, $area, $yield) = $sth->fetchrow)
    {
        next if exists $hFieldsHarvested{$tracking_number};
        $yield = 8.0 if $yield == 0.0;
        $hVolume{$week_number} += $yield * $area;
    }

    my $x = "x: [";
    my $y = "y: [";
    my $text = "[";

    foreach my $week (sort {$a <=> $b} keys %hVolume)
    {
        my $volume = $hVolume{$week};
        my $sVolume = sprintf("%.2f", $volume);
        $x .= "'$week', ";
        $y .= "$sVolume, ";
        my $str = sprintf("%.2f Ton. in week %d", $volume, $week);
        $text .= "'$str', ";
    }
    $x =~ s/, $/\]/g;
    $y =~ s/, $/\]/g;
    $text =~ s/, $/\],/g;

    my $str = "var trace1_gsm_volume = {\n\t$x,\n\t$y,\n\ntype: 'bar',\n\ttext: $text\n};\n";
    $str .= "var data_gsm_volume = [trace1_gsm_volume];\n";
    $str .= "var layout_gsm_volume = {\n";
    $str .= "\ttitle: 'Expected volume to be harvested (GSM)',\n";
    $str .= "showlegend: false,\n";
    $str .= "xaxis: { title: 'Harv.Week' },\n";
    $str .= "yaxis: { title: 'Volume (ton)' },\n";
    $str .= "};\n";
    $str .= "Plotly.plot('volume_per_week_interactive', data_gsm_volume, layout_gsm_volume, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub hybrids_per_day
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $query = "select distinct harv_date, COUNT(DISTINCT variety) from homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber') and plantnumber=? group by harv_date order by harv_date";
    my $sth = $dbh->prepare($query);
    $sth->execute($plantNumber);

    my $x = "x: [";
    my $y = "y: [";
    my $text = "[";

    while(my $line = $sth->fetchrow_arrayref)
    {
        my $date = $line->[0];
        my $hybrids = $line->[1];
        $x .= "'$date', ";
        $y .= "$hybrids, ";
        $text .= "'$hybrids hybrids in $date', ";
    }
    $x =~ s/, $/\]/g;
    $y =~ s/, $/\]/g;
    $text =~ s/, $/\],/g;

    my $str = "var trace1 = {\n\t$x,\n\t$y,\n\ntype: 'bar',\n\ttext: $text\n};\n";
    $str .= "var data = [trace1];\n";
    $str .= "var layout = {\n";
    $str .= "\ttitle: 'Expected number of hybrids per day',\n";
    $str .= "showlegend: false,\n";
    $str .= "xaxis: { type: 'date', title: 'Harv.Date' },\n";
    $str .= "yaxis: { title: '# of hybrids' },\n";
    $str .= "};\n";
    $str .= "Plotly.plot('hybrids_per_day', data, layout, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub hybrids_per_day_stack
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $sth;

    if($plantNumber == 1318 or $plant =~ "SPAIN") {
        my $query = "select distinct harv_date, variety from homresult where model_timestamp=(select(max(model_timestamp)) from homresult where plantnumber='$plantNumber' and plant='$plant') and plantnumber=? and plant=? order by harv_date, variety";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber, $plant);
    } else {
        my $query = "select distinct harv_date, variety from homresult where model_timestamp=(select(max(model_timestamp)) from homresult where plantnumber='$plantNumber' and plant not like '\%SPAIN\%')  and plantnumber=? and plant not like '\%SPAIN\%' order by harv_date, variety";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber);
    }

    my %hHybridharv_date = ();
    while(my ($harv_date, $hybrid) = $sth->fetchrow)
    {
        $hybrid =~ s/ STE//g;
        $hybrid =~ s/-/_/g;
        $hHybridharv_date{$hybrid}{$harv_date} = 1;
    }

    my $str = "";
    my @data = ();

    foreach my $hybrid (sort keys %hHybridharv_date)
    {
        my $x = "x: [";
        my $y = "y: [";

        foreach my $date (sort keys %{$hHybridharv_date{$hybrid}})
        {
            $x .= "'$date', ";
            $y .= "1, ";
        }
        $x =~ s/, $/\]/g;
        $y =~ s/, $/\]/g;

        $str .= "var trace_$hybrid = {\n";
        $str .= "\t$x,\n";
        $str .= "\t$y,\n";
        $str .= "\tname: '$hybrid',\n",
        $str .= "\ttype: 'bar'\n";
        $str .= "};\n\n";

        push @data, "trace_$hybrid";
    }

    $str .= "\nvar data_hybrids_per_day_stack = [";
    for (@data)
    {
        $str .= "$_, ";
    }
    $str =~ s/, $/\];/g;
    $str .= "\n\n";
    $str .= "var layout_hybrids_per_day_stack = {barmode: 'stack'};\n";
    $str .= "Plotly.plot('hybrids_per_day', data_hybrids_per_day_stack, layout_hybrids_per_day_stack, {showSendToCloud: true});\n";
    return $str;
}

#-----------------------------------------------------------------------------#
sub volume_per_day_stack
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $sth;
    

    if($plantNumber == 1318 or $plant =~ "SPAIN") {
        my $query = "select distinct harv_date, variety, sum(tonrw_harv) as total FROM homresult where model_timestamp=(select(max(model_timestamp)) from homresult where plantnumber='$plantNumber' and plant='$plant') and plantnumber = ? and plant = ? GROUP BY harv_date, variety order by harv_date, variety";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber, $plant);
    } else {
        my $query = "select distinct harv_date, variety, sum(tonrw_harv) as total FROM homresult where model_timestamp=(select(max(model_timestamp)) from homresult where plantnumber='$plantNumber' and plant not like '\%SPAIN\%') and plantnumber = ? and plant not like '\%SPAIN\%' GROUP BY harv_date, variety order by harv_date, variety";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber);
    }

    my %hHybridharv_date = ();
    while(my ($harv_date, $hybrid, $volume) = $sth->fetchrow)
    {
        $hybrid =~ s/ STE//g;
        $hybrid =~ s/-/_/g;
        $hHybridharv_date{$hybrid}{$harv_date} = $volume;
    }

    my $str = "";
    my @data = ();

    foreach my $hybrid (sort keys %hHybridharv_date)
    {
        my $x = "x: [";
        my $y = "y: [";

        foreach my $date (sort keys %{$hHybridharv_date{$hybrid}})
        {
            my $volume = $hHybridharv_date{$hybrid}{$date};
            $x .= "'$date', ";
            $y .= "$volume, ";
        }
        $x =~ s/, $/\]/g;
        $y =~ s/, $/\]/g;

        $str .= "var trace_vol_$hybrid = {\n";
        $str .= "\t$x,\n";
        $str .= "\t$y,\n";
        $str .= "\tname: '$hybrid',\n",
        $str .= "\ttype: 'bar'\n";
        $str .= "};\n\n";

        push @data, "trace_vol_$hybrid";
    }

    $str .= "\nvar data_volume_per_day_stack = [";
    for (@data)
    {
        $str .= "$_, ";
    }
    $str =~ s/, $/\];/g;
    $str .= "\n\n";
    $str .= "var layout_volume_per_day_stack = {barmode: 'stack'};\n";
    $str .= "Plotly.plot('volume_per_day', data_volume_per_day_stack, layout_volume_per_day_stack, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub volume_per_week_stack
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $sth;

    if($plantNumber == 1318 or $plant =~ "SPAIN") {
        my $query = "SELECT DISTINCT DATE_PART('week', harv_date) AS weekofyear, variety, sum(tonrw_harv) as total FROM homresult where model_timestamp=(select(max(model_timestamp)) from homresult where plantnumber='$plantNumber' and plant='$plant') and plantnumber=? and plant=? GROUP BY weekofyear, variety ORDER BY weekofyear, variety";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber, $plant);
    } else {
        my $query = "SELECT DISTINCT DATE_PART('week', harv_date) AS weekofyear, variety, sum(tonrw_harv) as total FROM homresult where model_timestamp=(select(max(model_timestamp)) from homresult where plantnumber='$plantNumber' and plant not like '\%SPAIN\%') and plantnumber=? and plant not like '\%SPAIN\%' GROUP BY weekofyear, variety ORDER BY weekofyear, variety";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber);
    }

    my %hHybridharv_date = ();
    while(my ($harv_date, $hybrid, $volume) = $sth->fetchrow)
    {
        $hybrid =~ s/ STE//g;
        $hybrid =~ s/-/_/g;
        $hHybridharv_date{$hybrid}{$harv_date} = $volume;
    }

    my $str = "";
    my @data = ();

    foreach my $hybrid (sort keys %hHybridharv_date)
    {
        my $x = "x: [";
        my $y = "y: [";

        foreach my $date (sort keys %{$hHybridharv_date{$hybrid}})
        {
            my $volume = $hHybridharv_date{$hybrid}{$date};
            $x .= "'$date', ";
            $y .= "$volume, ";
        }
        $x =~ s/, $/\]/g;
        $y =~ s/, $/\]/g;

        $str .= "var trace_vol_$hybrid = {\n";
        $str .= "\t$x,\n";
        $str .= "\t$y,\n";
        $str .= "\tname: '$hybrid',\n",
        $str .= "\ttype: 'bar'\n";
        $str .= "};\n\n";

        push @data, "trace_vol_$hybrid";
    }

    $str .= "\nvar data_volume_per_week_stack = [";
    for (@data)
    {
        $str .= "$_, ";
    }
    $str =~ s/, $/\];/g;
    $str .= "\n\n";
    $str .= "var layout_volume_per_week_stack = {barmode: 'stack'};\n";
    $str .= "Plotly.plot('volume_per_week', data_volume_per_week_stack, layout_volume_per_week_stack, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub area_per_day
{
    # SELECT DISTINCT strftime('%W', harv_date) AS weekofyear, SUM(area_harv) FROM homresult GROUP BY weekofyear ORDER BY weekofyear;
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $query = "SELECT DISTINCT harv_date, SUM(area_harv) FROM homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber') and plantnumber=? GROUP BY harv_date ORDER BY harv_date;";
    my $sth = $dbh->prepare($query);
    $sth->execute($plantNumber);

    my $x = "x: [";
    my $y = "y: [";
    my $text = "[";

    while(my $line = $sth->fetchrow_arrayref)
    {
        my $date = $line->[0];
        my $area = $line->[1];
        my $sArea = sprintf("%.2f", $area);
        $x .= "'$date', ";
        $y .= "$sArea, ";
        $text .= "'$sArea ha in $date', ";
    }
    $x =~ s/, $/\]/g;
    $y =~ s/, $/\]/g;
    $text =~ s/, $/\],/g;

    my $str = "var trace1 = {\n\t$x,\n\t$y,\n\ntype: 'bar',\n\ttext: $text\n};\n";
    $str .= "var data = [trace1];\n";
    $str .= "var layout = {\n";
    $str .= "\ttitle: 'Area harvested per day',\n";
    $str .= "showlegend: false,\n";
    $str .= "xaxis: { type: 'date', title: 'Harv.Date' },\n";
    $str .= "yaxis: { title: 'Area (ha)' },\n";
    $str .= "};\n";
    $str .= "Plotly.plot('area_per_day', data, layout, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub area_per_day_stack
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $sth;

    if($plantNumber == 1318 or $plant =~ "SPAIN") {
        my $query = "select distinct harv_date, picker, SUM(area_harv) as total FROM homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber' and plant='$plant') and plantnumber=? and plant=? GROUP BY harv_date, picker order by harv_date, picker";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber, $plant);
    } else {
        my $query = "select distinct harv_date, picker, SUM(area_harv) as total FROM homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber' and plant not like '\%SPAIN\%') and plantnumber=? and plant not like '\%SPAIN\%' GROUP BY harv_date, picker order by harv_date, picker";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber);
    }
    

    my %hZoneharv_date = ();
    while(my ($harv_date, $zone, $area) = $sth->fetchrow)
    {
        $hZoneharv_date{$zone}{$harv_date} = $area;
    }

    my $str = "";
    my @data = ();

    foreach my $zone (sort keys %hZoneharv_date)
    {
        my $x = "x: [";
        my $y = "y: [";

        foreach my $date (sort keys %{$hZoneharv_date{$zone}})
        {
            my $area = $hZoneharv_date{$zone}{$date};
            $x .= "'$date', ";
            $y .= "$area, ";
        }
        $x =~ s/, $/\]/g;
        $y =~ s/, $/\]/g;

        $str .= "var trace_area_$zone = {\n";
        $str .= "\t$x,\n";
        $str .= "\t$y,\n";
        $str .= "\tname: '$zone',\n",
        $str .= "\ttype: 'bar'\n";
        $str .= "};\n\n";

        push @data, "trace_area_$zone";
    }

    $str .= "\nvar data_area_per_day_stack = [";
    for (@data)
    {
        $str .= "$_, ";
    }
    $str =~ s/, $/\];/g;
    $str .= "\n\n";
    $str .= "var layout_area_per_day_stack = {barmode: 'stack'};\n";
    $str .= "Plotly.plot('area_per_day', data_area_per_day_stack, layout_area_per_day_stack, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub trucks_per_day_stack
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $sth;

    if($plantNumber == 1318 or $plant =~ "SPAIN") {
        my $query = "select distinct harv_date, picker, SUM(tonrw_harv) as total FROM homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber' and plant='$plant') and plantnumber=? and plant=? GROUP BY harv_date, picker order by harv_date, picker";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber, $plant);
    } else {
        my $query = "select distinct harv_date, picker, SUM(tonrw_harv) as total FROM homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber' and plant not like '\%SPAIN\%') and plantnumber=? and plant not like '\%SPAIN\%' GROUP BY harv_date, picker order by harv_date, picker";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber);
    }
    

    my $truck_capacity = 23; # tons / truck
    my %hZoneharv_date = ();
    while(my ($harv_date, $zone, $volume) = $sth->fetchrow)
    {
        my $trucks = $volume / $truck_capacity;
        $trucks = int($trucks + 0.5);
        $hZoneharv_date{$zone}{$harv_date} = $trucks;
    }

    my $str = "";
    my @data = ();

    foreach my $zone (sort keys %hZoneharv_date)
    {
        my $x = "x: [";
        my $y = "y: [";

        foreach my $date (sort keys %{$hZoneharv_date{$zone}})
        {
            my $trucks = $hZoneharv_date{$zone}{$date};
            $x .= "'$date', ";
            $y .= "$trucks, ";
        }
        $x =~ s/, $/\]/g;
        $y =~ s/, $/\]/g;

        $str .= "var trace_trucks_$zone = {\n";
        $str .= "\t$x,\n";
        $str .= "\t$y,\n";
        $str .= "\tname: '$zone',\n",
        $str .= "\ttype: 'bar'\n";
        $str .= "};\n\n";

        push @data, "trace_trucks_$zone";
    }

    $str .= "\nvar data_trucks_per_day_stack = [";
    for (@data)
    {
        $str .= "$_, ";
    }
    $str =~ s/, $/\];/g;
    $str .= "\n\n";
    $str .= "var layout_trucks_per_day_stack = {barmode: 'stack'};\n";
    $str .= "Plotly.plot('trucks_per_day', data_trucks_per_day_stack, layout_trucks_per_day_stack, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub trucks_per_week_stack
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $sth;

    if($plantNumber == 1318 or $plant =~ "SPAIN") {
        my $query = "SELECT DISTINCT DATE_PART('week', harv_date) AS weekofyear, picker, SUM(tonrw_harv) as total FROM homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber' and plant='$plant') and plantnumber=? and plant=? GROUP BY weekofyear, picker order by weekofyear, picker";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber, $plant);
    } else {
        my $query = "SELECT DISTINCT DATE_PART('week', harv_date) AS weekofyear, picker, SUM(tonrw_harv) as total FROM homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber' and plant not like '\%SPAIN\%') and plantnumber=? and plant not like '\%SPAIN\%' GROUP BY weekofyear, picker order by weekofyear, picker";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber);
    }

    my $truck_capacity = 23; # tons / truck
    my %hZoneharv_date = ();
    while(my ($harv_date, $zone, $volume) = $sth->fetchrow)
    {
        my $trucks = $volume / $truck_capacity;
        $trucks = int($trucks + 0.5);
        $hZoneharv_date{$zone}{$harv_date} = $trucks;
    }

    my $str = "";
    my @data = ();

    foreach my $zone (sort keys %hZoneharv_date)
    {
        my $x = "x: [";
        my $y = "y: [";

        foreach my $date (sort keys %{$hZoneharv_date{$zone}})
        {
            my $trucks = $hZoneharv_date{$zone}{$date};
            $x .= "'$date', ";
            $y .= "$trucks, ";
        }
        $x =~ s/, $/\]/g;
        $y =~ s/, $/\]/g;

        $str .= "var trace_trucks_$zone = {\n";
        $str .= "\t$x,\n";
        $str .= "\t$y,\n";
        $str .= "\tname: '$zone',\n",
        $str .= "\ttype: 'bar'\n";
        $str .= "};\n\n";

        push @data, "trace_trucks_$zone";
    }

    $str .= "\nvar data_trucks_per_week_stack = [";
    for (@data)
    {
        $str .= "$_, ";
    }
    $str =~ s/, $/\];/g;
    $str .= "\n\n";
    $str .= "var layout_trucks_per_week_stack = {barmode: 'stack'};\n";
    $str .= "Plotly.plot('trucks_per_week', data_trucks_per_week_stack, layout_trucks_per_week_stack, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub lateness_fields
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $sth;

    if($plantNumber == 1318 or $plant =~ "SPAIN") {
        my $query = "SELECT DISTINCT lateness, COUNT(DISTINCT field) FROM homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber' and plant='$plant') and plantnumber=? and plant=? GROUP BY lateness ORDER BY lateness";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber, $plant);
    } else {
        my $query = "SELECT DISTINCT lateness, COUNT(DISTINCT field) FROM homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber' and plant not like '\%SPAIN\%') and plantnumber=? and plant not like '\%SPAIN\%' GROUP BY lateness ORDER BY lateness";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber);
    }
    

    my $x = "x: [";
    my $y = "y: [";
    my $text = "[";
    my $annotations = "var annotations_lateness_fields = [\n";

    while(my $line = $sth->fetchrow_arrayref)
    {
        my $lateness = $line->[0];
        my $fields   = $line->[1];
        $x .= "$lateness, ";
        $y .= "$fields, ";
        $text .= "'$fields fields with lateness $lateness', ";

        $annotations .= "{ x: '$lateness', y: $fields + 5, text: '$fields', xanchor: 'center', yanchor: 'botton', showarrow: false}, ";
    }
    $x =~ s/, $/\]/g;
    $y =~ s/, $/\]/g;
    $text =~ s/, $/\],/g;
    $annotations =~ s/, $/\];/g;

    my $str = "var lateness_fields = {\n\t$x,\n\t$y,\n\ntype: 'bar',\n\ttext: $text\n};\n";
    $str .= "$annotations\n";
    $str .= "var data_lateness_fields = [lateness_fields];\n";
    $str .= "var layout_lateness_fields = {\n";
    $str .= "\ttitle: 'lateness per # of fields',\n";
    $str .= "\tannotations: annotations_lateness_fields,\n";
    $str .= "showlegend: false,\n";
    $str .= "xaxis: { type: 'category', title: 'lateness (days)' },\n";
    $str .= "yaxis: { title: '# of fields' },\n";
    $str .= "};\n";
    $str .= "Plotly.plot('lateness_fields', data_lateness_fields, layout_lateness_fields, {showSendToCloud: true, responsive: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub lateness_volume
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $sth;

    if($plantNumber == 1318 or $plant =~ "SPAIN") {
        my $query = "SELECT DISTINCT lateness, SUM(tonrw_harv) FROM homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber' and plant='$plant') and plantnumber=? and plant=? GROUP BY lateness ORDER BY lateness";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber, $plant);
    } else {
        my $query = "SELECT DISTINCT lateness, SUM(tonrw_harv) FROM homresult where model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber' and plant not like '\%SPAIN\%') and plantnumber=? and plant not like '\%SPAIN\%' GROUP BY lateness ORDER BY lateness";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber);
    }
    

    my $x = "x: [";
    my $y = "y: [";
    my $text = "[";
    my $annotations = "var annotations_lateness_volume = [\n";

    while(my $line = $sth->fetchrow_arrayref)
    {
        my $lateness = $line->[0];
        my $volume   = $line->[1];
        $x .= "$lateness, ";
        my $sVolume = sprintf("%.2f", $volume);
        $y .= "$volume, ";
        $text .= "'$sVolume Ton.RW with lateness $lateness', ";

        $annotations .= "{ x: '$lateness', y: $volume + 2000, text: '$sVolume', xanchor: 'center', yanchor: 'botton', showarrow: false}, ";
    }
    $x =~ s/, $/\]/g;
    $y =~ s/, $/\]/g;
    $text =~ s/, $/\],/g;
    $annotations =~ s/, $/\];/g;

    my $str = "var lateness_volume = {\n\t$x,\n\t$y,\n\ntype: 'bar',\n\ttext: $text\n};\n";
    $str .= "$annotations\n";
    $str .= "var data_lateness_volume = [lateness_volume];\n";
    $str .= "var layout_lateness_volume = {\n";
    $str .= "\ttitle: 'lateness per Volume (Ton.RW)',\n";
    $str .= "\tannotations: annotations_lateness_volume,\n";
    $str .= "showlegend: false,\n";
    $str .= "xaxis: { type: 'category', title: 'lateness (days)' },\n";
    $str .= "yaxis: { title: 'Volume (Ton.RW)' },\n";
    $str .= "};\n";
    $str .= "Plotly.plot('lateness_volume', data_lateness_volume, layout_lateness_volume, {showSendToCloud: true, responsive: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub area_per_picker
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $sth;

    if($plantNumber == 1318 or $plant =~ "SPAIN") {
        my $query = "select distinct cluster, sum(area) as total_area, count(*) as qtty_fields from fieldhom where sitekey=? and region=? group by cluster order by cluster";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber, $plant);
    } else {
        my $query = "select distinct cluster, sum(area) as total_area, count(*) as qtty_fields from fieldhom where sitekey=? and region not like '\%SPAIN\%' group by cluster order by cluster";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber);
    }
    

    my $x = "x: [";
    my $y = "y: [";
    my $text = "[";
    my $annotations = "var annotations_area_picker = [\n";

    while(my $line = $sth->fetchrow_arrayref)
    {
        my $picker = $line->[0];
        my $area   = $line->[1];

        if($picker eq 'GR1' or $picker eq 'GR2')
        {
            $area = ceil($area / 3);
        } else {
            $area = ceil($area / 2);
        }

        $x .= "'$picker', ";
        my $sArea = sprintf("%.2f", $area);
        $y .= "$area, ";
        $text .= "'$sArea ha, picker group $picker', ";

        $annotations .= "{ x: '$picker', y: $area + 2, text: '$sArea', xanchor: 'center', yanchor: 'botton', showarrow: false}, ";
    }
    $x =~ s/, $/\]/g;
    $y =~ s/, $/\]/g;
    $text =~ s/, $/\],/g;
    $annotations =~ s/, $/\];/g;

    my $str = "var area_picker = {\n\t$x,\n\t$y,\n\ntype: 'bar',\n\ttext: $text\n};\n";
    $str .= "$annotations\n";
    $str .= "var data_area_picker = [area_picker];\n";
    $str .= "var layout_area_picker = {\n";
    $str .= "\ttitle: 'Area per Picker (ha)',\n";
    $str .= "\tannotations: annotations_area_picker,\n";
    $str .= "\tshowlegend: false,\n";
    $str .= "\txaxis: { type: 'category', title: 'Picker Group' },\n";
    $str .= "\tyaxis: { title: 'Area (ha)' },\n";
    $str .= "};\n";
    $str .= "Plotly.plot('plt_area_picker', data_area_picker, layout_area_picker, {showSendToCloud: true, responsive: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub fields_per_picker
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $sth;
    if($plantNumber == 1318 or $plant =~ "SPAIN") {
        my $query = "select distinct cluster, sum(area) as total_area, count(*) as qtty_fields from fieldhom where sitekey=? and region=? group by cluster order by cluster";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber, $plant);
    } else {
        my $query = "select distinct cluster, sum(area) as total_area, count(*) as qtty_fields from fieldhom where sitekey=? and region not like '\%SPAIN\%' group by cluster order by cluster";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber);
    }

    my $x = "x: [";
    my $y = "y: [";
    my $text = "[";
    my $annotations = "var annotations_fields_picker = [\n";

    while(my $line = $sth->fetchrow_arrayref)
    {
        my $picker = $line->[0];
        my $fields   = $line->[2];

        if($picker eq 'GR1' or $picker eq 'GR2')
        {
            $fields = ceil($fields / 3);
        } else {
            $fields = ceil($fields / 2);
        }

        $x .= "'$picker', ";
        $y .= "$fields, ";
        $text .= "'$fields fields assigned to picker group $picker', ";

        $annotations .= "{ x: '$picker', y: $fields + 2, text: '$fields', xanchor: 'center', yanchor: 'botton', showarrow: false}, ";
    }
    $x =~ s/, $/\]/g;
    $y =~ s/, $/\]/g;
    $text =~ s/, $/\],/g;
    $annotations =~ s/, $/\];/g;

    my $str = "var fields_picker = {\n\t$x,\n\t$y,\n\ttype: 'bar',\n\ttext: $text\n};\n";
    $str .= "$annotations\n";
    $str .= "var data_fields_picker = [fields_picker];\n";
    $str .= "var layout_fields_picker = {\n";
    $str .= "\ttitle: 'Fields per Picker',\n";
    $str .= "\tannotations: annotations_fields_picker,\n";
    $str .= "\tshowlegend: false,\n";
    $str .= "\txaxis: { type: 'category', title: 'Picker Group' },\n";
    $str .= "\tyaxis: { title: '# of fields' },\n";
    $str .= "};\n";
    $str .= "Plotly.plot('plt_fields_picker', data_fields_picker, layout_fields_picker, {showSendToCloud: true, responsive: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub volume_per_day_stack_period
{
    my $dbh = $_[0];
    my $start_date = $_[1];
    my $plant = $_[2];
    my $plantNumber = $_[3];

    my %hFieldsToHarvest = ();
    my $sth;
    if($plantNumber == 1318 or $plant =~ "SPAIN") {
        my $query = "select tracking_number, harv_date from homresult WHERE part = 1 and plantnumber=? and plant=?";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber, $plant);
    } else {
        my $query = "select tracking_number, harv_date from homresult WHERE part = 1 and plantnumber=? and plant not like '\%SPAIN\%'";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber);
    }

    
    while(my ($field, $actual_harvest_date) = $sth->fetchrow)
    {
        $hFieldsToHarvest{$field} = $actual_harvest_date;
    }
    $sth->finish;

    my $key = "(";
    for my $field (keys %hFieldsToHarvest)
    {
        $key .= "'$field" . "01',";
    }
    $key =~ s/,$/\)/;
    
    return if not isvaliddate($start_date);

    my ($year, $month, $day) = split /-/, $start_date;
    ($year, $month, $day) = Add_Delta_Days($year, $month, $day, 10);
    my $end_date = sprintf("%04d-%02d-%02d", $year, $month, $day);

    if($plantNumber == 1318 or $plant =~ "SPAIN") {
        my $query = "SELECT DISTINCT harv_date, variety, SUM(tonrw_harv) AS total FROM homresult WHERE plantnumber=? and plant=? and harv_date >= ? and harv_date <= ? and field in $key GROUP BY harv_date, variety ORDER BY harv_date, variety";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber, $plant, $start_date, $end_date);
    } else {
        my $query = "SELECT DISTINCT harv_date, variety, SUM(tonrw_harv) AS total FROM homresult WHERE plantnumber=? and harv_date >= ? and harv_date <= ? and plant not like '\%SPAIN\%' and field in $key GROUP BY harv_date, variety ORDER BY harv_date, variety";
        $sth = $dbh->prepare($query);
        $sth->execute($plantNumber, $start_date, $end_date);
    }
    

    my %hHybridharv_date = ();
    while(my ($harv_date, $hybrid, $volume) = $sth->fetchrow)
    {
        $hybrid =~ s/ STE//g;
        $hybrid =~ s/-/_/g;
        $hHybridharv_date{$hybrid}{$harv_date} = $volume;
    }

    my $str = "";
    my @data = ();

    foreach my $hybrid (sort keys %hHybridharv_date)
    {
        my $x = "x: [";
        my $y = "y: [";
        my $text = "text: [";

        foreach my $date (sort keys %{$hHybridharv_date{$hybrid}})
        {
            my $volume = $hHybridharv_date{$hybrid}{$date};
            $x .= "'$date', ";
            $y .= "$volume, ";
            $text .= "'$hybrid', ";
        }
        $x =~ s/, $/\]/g;
        $y =~ s/, $/\]/g;
        $text =~ s/, $/\]/g;

        $str .= "var trace_vol_$hybrid = {\n";
        $str .= "\t$x,\n";
        $str .= "\t$y,\n";
        $str .= "\t$text,\n";
        $str .= "\tname: '$hybrid',\n",
        $str .= "\ttype: 'bar'\n";
        $str .= "};\n\n";

        push @data, "trace_vol_$hybrid";
    }

    $str .= "\nvar data_volume_per_day_stack = [";
    for (@data)
    {
        $str .= "$_, ";
    }
    $str =~ s/, $/\];/g;
    $str .= "\n\n";
    $str .= "var layout_volume_per_day_stack = {barmode: 'stack'};\n";
    $str .= "Plotly.plot('volume_per_day', data_volume_per_day_stack, layout_volume_per_day_stack, {showSendToCloud: true});\n";

    my $js_code = <<"END_MSG";
    var myPlot = document.getElementById('volume_per_day'),
        data = data_volume_per_day_stack,
        layout = {
            hovermode:'closest',
            barmode: 'stack',
            title:'Ton.RW per day'
        };

    Plotly.newPlot('volume_per_day', data, layout);

    myPlot.on('plotly_click', function(data){
        var harv_date = '';
        var hybrid = '';

        \$("#tbl_fields_selected").find("tr:not(:first)").remove();
        
        for(var i=0; i < data.points.length; i++)
        {
            harv_date = data.points[i].x;
            hybrid = data.points[i].text;
        }
        var dataString = "harv_date=" + harv_date + "&hybrid=" + hybrid + "&plant=$plant&plantNumber=$plantNumber" ;
        console.log(dataString);
        
        \$.ajax(
        {
            type: "GET",
            url: "/fields_per_day",
            data: dataString,
            crossDomain: true,
            cache: false,
            beforeSend: function () { \$('#loadingDiv').text("Loading. Please wait..."); },
            success: function (json_data) {

                var obj = jQuery.parseJSON(json_data);
                \$.each(obj, function(key,value) 
                {
                    var row = \$('<tr>');
                    row.append(\$('<td>').html(value.field));
                    row.append(\$('<td>').html(value.picker));
                    row.append(\$('<td>').html(value.variety));
                    row.append(\$('<td>').html(value.harv_date));
                    row.append(\$('<td>').html(value.total_area));
                    row.append(\$('<td>').html(value.area_harv));
                    row.append(\$('<td>').html(value.total_tonrw));
                    row.append(\$('<td>').html(value.tonrw_harv));
                    row.append(\$('<td>').html(value.lateness));
                    row.append(\$('<td>').html(value.moisture));
                    \$('#tbl_fields_selected').append(row);
                }); 
            },
            complete: function () { \$('#loadingDiv').text("Please click in one of the bars in the graph above"); },
            error: function (jqXHR, exception) {
                var msg = '';
                if (jqXHR.status === 0) {
                    msg = 'Not connected. Please check the network.';
                } else if (jqXHR.status == 404) {
                    msg = 'Page not found. [404]';
                } else if (jqXHR.status == 500) {
                    msg = 'Internal server error [500].';
                } else if (exception === 'parsererror') {
                    msg = 'Failed to parse answer (JSON).';
                } else if (exception === 'timeout') {
                    msg = 'Time limit exceeded.';
                } else if (exception === 'abort') {
                    msg = 'Aborted Ajax request.';
                } else {
                    msg = 'Unknown error.' + jqXHR.responseText;
                }
                alert(msg);
            }
        });
    });
END_MSG

    $str .= $js_code;


    return $str;
}
#-----------------------------------------------------------------------------#
sub barplot_date_moisture
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $query = "select distinct trackingNumber, plantNumber, lastHarvestReceiptDate, moisturePercentage from contract order by trackingNumber, plantNumber";
    my $sth = $dbh->prepare($query);
    $sth->execute;
    my %hActuals = ();
    while(my $row = $sth->fetchrow_hashref)
    {
        if(exists $row->{'lastHarvestReceiptDate'} and isvaliddate($row->{'lastHarvestReceiptDate'}) and looks_like_number($row->{'moisturePercentage'}) and $row->{'moisturePercentage'} > 0)
        {
            $hActuals{$row->{'plantNumber'}}{'date'}++ if $row->{'lastHarvestReceiptDate'} ne '0000-00-00';
            $hActuals{$row->{'plantNumber'}}{'moisture'}++ if $row->{'moisturePercentage'} + 0 > 0;
        }
    }
    $sth->finish;

    my $x_value = "var xValue = [";
    my $y_value = "var yValue = [";
    my $y_value2= "var yValue2 = [";

    foreach my $zona (sort keys %hActuals)
    {
        $x_value .= "'$zona',";
        if(exists $hActuals{$zona}{'date'})
        {
            $y_value .= $hActuals{$zona}{'date'} . ",";
        } else {
            $y_value .= "0,";
        }

        if(exists $hActuals{$zona}{'moisture'})
        {
            $y_value2 .= $hActuals{$zona}{'moisture'} . ",";
        } else {
            $y_value2 .= "0,";
        }
    }
    $x_value =~ s/,$/\];/g;
    $y_value =~ s/,$/\];/g;
    $y_value2 =~ s/,$/\];/g;

    my $js_code = <<"END_MSG";
    $x_value
    $y_value
    $y_value2
    
    var trace1 = {
    x: xValue,
    y: yValue,
    type: 'bar',
    name: 'with harv.date',
    text: yValue.map(String),
    textposition: 'auto',
    hoverinfo: 'none',
    opacity: 0.5,
    marker: {
        color: 'rgb(158,202,225)',
        line: {
        color: 'rgb(8,48,107)',
        width: 1.5
        }
    }
    };

    var trace2 = {
    x: xValue,
    y: yValue2,
    type: 'bar',
    name: 'with harv.moisture',
    text: yValue2.map(String),
    textposition: 'auto',
    hoverinfo: 'none',
    marker: {
        color: 'rgba(58,200,225,.5)',
        line: {
        color: 'rgb(8,48,107)',
        width: 1.5
        }
    }
    };

    var data = [trace1,trace2];

    var layout = {
    title: 'Fields with actual harvest dates in Scout x with actual harvest moistures in Contracts API'
    };

    Plotly.newPlot('barplot_date_moisture', data, layout);

END_MSG

    return $js_code;
}

#-----------------------------------------------------------------------------#
sub barplot_date_moisture_total
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $query = "select distinct trackingNumber, lastHarvestReceiptDate, moisturePercentage from contract order by trackingNumber";
    my $sth = $dbh->prepare($query);
    $sth->execute;
    my %hActuals = ();
    while(my $row = $sth->fetchrow_hashref)
    {
        if(exists $row->{'lastHarvestReceiptDate'} and isvaliddate($row->{'lastHarvestReceiptDate'}) and looks_like_number($row->{'moisturePercentage'}) and $row->{'moisturePercentage'} > 0)
        {
            $hActuals{'date'}++ if $row->{'actual_harvest_date'} ne '0000-00-00';
            $hActuals{'moisture'}++ if $row->{'actual_harvest_moisture'} + 0 > 0;
        }
    }
    $sth->finish;

    my $x_value = "var xValue = [";
    my $y_value = "var yValue = [";
    my $y_value2= "var yValue2 = [";

    
    $x_value .= "'Actuals',";
    if(exists $hActuals{'date'})
    {
        $y_value .= $hActuals{'date'} . ",";
    } else {
        $y_value .= "0,";
    }

    if(exists $hActuals{'moisture'})
    {
        $y_value2 .= $hActuals{'moisture'} . ",";
    } else {
        $y_value2 .= "0,";
    }
    
    $x_value =~ s/,$/\];/g;
    $y_value =~ s/,$/\];/g;
    $y_value2 =~ s/,$/\];/g;

    my $js_code = <<"END_MSG";
    $x_value
    $y_value
    $y_value2
    
    var trace1 = {
    x: xValue,
    y: yValue,
    type: 'bar',
    name: 'with harv.date',
    text: yValue.map(String),
    textposition: 'auto',
    hoverinfo: 'none',
    opacity: 0.5,
    marker: {
        color: 'rgb(158,202,225)',
        line: {
        color: 'rgb(8,48,107)',
        width: 1.5
        }
    }
    };

    var trace2 = {
    x: xValue,
    y: yValue2,
    type: 'bar',
    name: 'with harv.moisture',
    text: yValue2.map(String),
    textposition: 'auto',
    hoverinfo: 'none',
    marker: {
        color: 'rgba(58,200,225,.5)',
        line: {
        color: 'rgb(8,48,107)',
        width: 1.5
        }
    }
    };

    var data = [trace1,trace2];

    var layout = {
    title: 'Fields with actual harv. dates x actual harv. moistures'
    };

    Plotly.newPlot('barplot_date_moisture_total', data, layout);

END_MSG

    return $js_code;
}

#-----------------------------------------------------------------------------#

sub actual_moisture_bubble
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $query = "select t1.lot, t1.lowest_harvest_moisture, t1.highest_harvest_moisture, t2.moisturePercentage from fieldhom as t1, contract as t2 where t1.lot=t2.trackingNumber and t2.moisturePercentage > 0";
    my $sth = $dbh->prepare($query);
    $sth->execute;

    my %hHOM = %{&get_harv_dates_hom($dbh, $plant, $plantNumber)};

    my (%hActual, %hFieldLB, %hFieldUB) = ();
    my $n = 0; # number of rows.
    my $avg_moisture_hom = 0;
    my $avg_moisture_actual = 0;

    while(my ($tracking_number, $lb, $ub, $actual_harvest_moisture) = $sth->fetchrow)
    {
        $n++;
        $hFieldLB{$tracking_number} = $lb + 0;
        $hFieldUB{$tracking_number} = $ub + 0;
        $hActual{$tracking_number} = $actual_harvest_moisture;
        $avg_moisture_actual += $actual_harvest_moisture;
    }
    $avg_moisture_actual /= $n if $n > 0;
    $avg_moisture_actual = sprintf("%.0f", $avg_moisture_actual);

    #-------------------------------------------------------------#
    # Actual
    my $var_actual = "var trace_actual_moisture = {\n";
    my $x_actual = "x: [";
    my $y_actual = "y: [";
    my $txt_actual = "text: [";
    my $marker_actual = "marker: {size: [";
    foreach my $tracking_number (sort keys %hActual)
    {
        my $moisture = $hActual{$tracking_number};
        $moisture = sprintf("%.0f", $moisture);
        $x_actual .= "'$tracking_number',";
        $y_actual .= "$moisture,";
        $txt_actual .= "'$tracking_number : $moisture',";
        $marker_actual .= "$moisture,";
    }
    $x_actual =~ s/,$/\],\n/g;
    $y_actual =~ s/,$/\],\n/g;
    $txt_actual =~ s/,$/\],\n/g;
    $marker_actual =~ s/,$/\],\n/g;
    $marker_actual .= "sizemode: 'area'},\nmode: 'markers',\nname: 'Actual'};\n";
    $var_actual .= $x_actual . $y_actual . $txt_actual . $marker_actual;

    #-------------------------------------------------------------#
    # HOM
    my $var_hom = "var trace_hom_moisture = {\n";
    my $x_hom = "x: [";
    my $y_hom = "y: [";
    my $txt_hom = "text: [";
    my $marker_hom = "marker: {size: [";
    foreach my $tracking_number (sort keys %hActual)
    {
        my ($hom_harv_date, $moisture, $hom_harv_date2) = split /;/, $hHOM{$tracking_number};
        $avg_moisture_hom += $moisture;
        $moisture = sprintf("%.0f", $moisture);
        $x_hom .= "'$tracking_number',";
        $y_hom .= "$moisture,";
        $txt_hom .= "'$tracking_number : $moisture',";
        $marker_hom .= "$moisture,";
    }
    $x_hom =~ s/,$/\],\n/g;
    $y_hom =~ s/,$/\],\n/g;
    $txt_hom =~ s/,$/\],\n/g;
    $marker_hom =~ s/,$/\],\n/g;
    $marker_hom .= "sizemode: 'area'},\nmode: 'markers',\nname: 'HOM'};\n";
    $var_hom .= $x_hom . $y_hom . $txt_hom . $marker_hom;
    $avg_moisture_hom /= $n if $n > 0;
    $avg_moisture_hom = sprintf("%.0f", $avg_moisture_hom);
    #-------------------------------------------------------------#
    # Line average moisture HOM.
    my $var_avg_hom = "var trace_avg_hom_moisture = {\n";
    my $x_avg_hom = "x: [";
    my $y_avg_hom = "y: [";
    foreach my $tracking_number (sort keys %hActual)
    {
        $x_avg_hom .= "'$tracking_number',";
        $y_avg_hom .= "$avg_moisture_hom,";
    }
    $x_avg_hom =~ s/,$/\],\n/g;
    $y_avg_hom =~ s/,$/\],\n/g;
    $var_avg_hom .= $x_avg_hom . $y_avg_hom . "mode: 'lines',\nname: 'Avg.HOM'};\n";

    #-------------------------------------------------------------#
    # Line Upper bound in optimial moisture range.
    my $var_line_ub = "var trace_line_ub = {\n";
    my $x_ub = "x: [";
    my $y_ub = "y: [";
    foreach my $tracking_number (sort keys %hActual)
    {
        my $ub = 33;
        $ub = $hFieldUB{$tracking_number} if exists $hFieldUB{$tracking_number};
        $x_ub .= "'$tracking_number',";
        $y_ub .= "$ub,";
    }
    $x_ub =~ s/,$/\],\n/g;
    $y_ub =~ s/,$/\],\n/g;
    $var_line_ub .= $x_ub . $y_ub . "mode: 'lines',\nfill: 'tonexty',\nfillcolor: 'rgba(0, 255, 0, 0.15)',\nline: {width: 0},\nname: 'Opt.Moist.UB'};\n";
    #-------------------------------------------------------------#
    # Line lower bound in optimial moisture range.
    my $var_line_lb = "var trace_line_lb = {\n";
    my $x_lb = "x: [";
    my $y_lb = "y: [";
    foreach my $tracking_number (sort keys %hActual)
    {
        my $lb = 25;
        $lb = $hFieldLB{$tracking_number} if exists $hFieldLB{$tracking_number};
        $x_lb .= "'$tracking_number',";
        $y_lb .= "$lb,";
    }
    $x_lb =~ s/,$/\],\n/g;
    $y_lb =~ s/,$/\],\n/g;
    $var_line_lb .= $x_lb . $y_lb . "mode: 'lines',\nfill: 'tonexty',\nfillcolor: 'rgba(0, 255, 0, 0.15)',\nline: {width: 0},\nname: 'Opt.Moist.LB'};\n";

    #-------------------------------------------------------------#
    # Line average moisture Actual.
    my $var_avg_actual = "var trace_avg_actual_moisture = {\n";
    my $x_avg_actual = "x: [";
    my $y_avg_actual = "y: [";
    foreach my $tracking_number (sort keys %hActual)
    {
        $x_avg_actual .= "'$tracking_number',";
        $y_avg_actual .= "$avg_moisture_actual,";
    }
    $x_avg_actual =~ s/,$/\],\n/g;
    $y_avg_actual =~ s/,$/\],\n/g;
    $var_avg_actual .= $x_avg_actual . $y_avg_actual . "mode: 'lines',\nname: 'Avg.Actual'};\n";
    #-------------------------------------------------------------#

    my $str = "";
    $str .= $var_actual . $var_hom . $var_avg_hom . $var_avg_actual . $var_line_lb . $var_line_ub;
    $str .= "var data_moisture_bubble = [trace_actual_moisture, trace_hom_moisture, trace_avg_hom_moisture, trace_avg_actual_moisture, trace_line_ub, trace_line_lb];\n";
    $str .= "var layout_moisture_bubble = { title: 'Moisture Actual x Model', showlegend: true, yaxis: { title: { text: 'Moisture (%)',} }, };\n";
    $str .= "Plotly.newPlot('actual_moisture_bubble', data_moisture_bubble, layout_moisture_bubble);";

    #-------------------------------------------------------------#

    return $str;
}
#-----------------------------------------------------------------------------#
sub get_harv_dates_hom
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $query = "SELECT tracking_number, harv_date, moisture FROM homresult WHERE part = 1 and model_timestamp=(select max(model_timestamp) from homresult where plantnumber='$plantNumber') and plantnumber=?";
    my $sth = $dbh->prepare($query);
    $sth->execute($plantNumber);
    my %hash;
    while(my ($field, $harv_date, $moisture) = $sth->fetchrow)
    {
        $field = substr($field, 0, -2);
        $hash{$field} = "$harv_date;$moisture;$harv_date";
    }
    $sth->finish;
    return \%hash;
}
#-----------------------------------------------------------------------------#
sub isvaliddate {
  my $input = shift;
  if ($input =~ m!^((?:19|20)\d\d)[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])$!) {
    # At this point, $1 holds the year, $2 the month and $3 the day of the date entered
    if ($3 == 31 and ($2 == 4 or $2 == 6 or $2 == 9 or $2 == 11)) {
      return 0; # 31st of a month with 30 days
    } elsif ($3 >= 30 and $2 == 2) {
      return 0; # February 30th or 31st
    } elsif ($2 == 2 and $3 == 29 and not ($1 % 4 == 0 and ($1 % 100 != 0 or $1 % 400 == 0))) {
      return 0; # February 29th outside a leap year
    } else {
      return 1; # Valid date
    }
  } else {
    return 0; # Not a date
  }
}
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#
#-----------------------------------------------------------------------------#
#
# Plot regions
sub plot_regions
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];

    my $query = "select distinct region from fieldhom where sitekey=? and region not like '\%SPAIN\%' ";
    my $sth = $dbh->prepare($query);
    $sth->execute($plantNumber);
    my @regions = ();
    while(my ($region) = $sth->fetchrow)
    {
        push @regions, $region;
    }
    $sth->finish;

    my $return_str = "";
    #---------------------------------------------------------------------------#
    # for each region create the first graph (volume / day)
    for my $region (@regions)
    {
        my $region2 = lc $region;
        $region2 =~ s/\s+/_/g;
        my $g = &volume_per_day_stack_region($dbh, $plant, $plantNumber, $region);

        my $message = <<"END_MESSAGE";
        <div class="row">
            <div class="col-lg-12">
                <div class="panel panel-default">
                    <div class="panel-heading">
                        <i class="fa fa-bar-chart-o fa-fw"></i> Expected volume per day: <span style="color:red">$region</span>
                    </div>
                    <div class="panel-body">
                        <div style="max-width: 100%; margin: auto" id="expected_volume_per_day_$region2"></div>
                    </div>
                </div>
            </div>
        </div>
        <script type="text/javascript">
        $g
        </script>
END_MESSAGE
        $return_str .= $message . "\n";
    }
    #---------------------------------------------------------------------------#
    #---------------------------------------------------------------------------#
    # Hybrids per day
    for my $region (@regions)
    {
        my $region2 = lc $region;
        $region2 =~ s/\s+/_/g;
        my $g = &hybrids_per_day_stack_region($dbh, $plant, $plantNumber, $region);

        my $message = <<"END_MESSAGE";
        <div class="row">
            <div class="col-lg-12">
                <div class="panel panel-default">
                    <div class="panel-heading">
                        <i class="fa fa-bar-chart-o fa-fw"></i> Expected number of hybrids per day: <span style="color:red">$region</span>
                    </div>
                    <div class="panel-body">
                        <div style="max-width: 100%; margin: auto" id="hybrids_per_day_$region2"></div>
                    </div>
                </div>
            </div>
        </div>
        <script type="text/javascript">
        $g
        </script>
END_MESSAGE
        $return_str .= $message . "\n";
    }
    #---------------------------------------------------------------------------#
    #---------------------------------------------------------------------------#
    # Lateness (fields)
    for my $region (@regions)
    {
        my $region2 = lc $region;
        $region2 =~ s/\s+/_/g;
        my $g = &lateness_fields_region($dbh, $plant, $plantNumber, $region);

        my $message = <<"END_MESSAGE";
        <div class="row">
            <div class="col-lg-12">
                <div class="panel panel-default">
                    <div class="panel-heading">
                        <i class="fa fa-bar-chart-o fa-fw"></i> Lateness - Fields assigned to <span style="color:red">$region</span>
                    </div>
                    <div class="panel-body">
                        <div style="max-width: 100%; margin: auto" id="lateness_fields_$region2"></div>
                    </div>
                </div>
            </div>
        </div>
        <script type="text/javascript">
        $g
        </script>
END_MESSAGE
        $return_str .= $message . "\n";
    }
    #---------------------------------------------------------------------------#
    #---------------------------------------------------------------------------#
    # Lateness (volume)
    for my $region (@regions)
    {
        my $region2 = lc $region;
        $region2 =~ s/\s+/_/g;
        my $g = &lateness_volume_region($dbh, $plant, $plantNumber, $region);

        my $message = <<"END_MESSAGE";
        <div class="row">
            <div class="col-lg-12">
                <div class="panel panel-default">
                    <div class="panel-heading">
                        <i class="fa fa-bar-chart-o fa-fw"></i> Lateness - Volume (Ton.RW) assigned to <span style="color:red">$region</span>
                    </div>
                    <div class="panel-body">
                        <div style="max-width: 100%; margin: auto" id="lateness_volume_$region2"></div>
                    </div>
                </div>
            </div>
        </div>
        <script type="text/javascript">
        $g
        </script>
END_MESSAGE
        $return_str .= $message . "\n";
    }
    #---------------------------------------------------------------------------#

    return $return_str;
}
#-----------------------------------------------------------------------------#
sub lateness_volume_region
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $region = $_[3];
    my $query = "SELECT DISTINCT t1.lateness, SUM(t1.tonrw_harv) FROM homresult as t1, fieldhom as t2 where t1.plantnumber=? and t2.region=? and t1.plant not like '\%SPAIN\%'  and t1.tracking_number = t2.lot GROUP BY lateness ORDER BY lateness";
    my $sth = $dbh->prepare($query);
    $sth->execute($plantNumber, $region);

    my $region2 = lc $region;
    $region2 =~ s/\s+/_/g;

    my $x = "x: [";
    my $y = "y: [";
    my $text = "[";
    my $annotations = "var annotations_lateness_volume_$region2 = [\n";

    while(my $line = $sth->fetchrow_arrayref)
    {
        my $lateness = $line->[0];
        my $volume   = $line->[1];
        $x .= "$lateness, ";
        my $sVolume = sprintf("%.2f", $volume);
        $y .= "$volume, ";
        $text .= "'$sVolume Ton.RW with lateness $lateness', ";

        $annotations .= "{ x: '$lateness', y: $volume + 2000, text: '$sVolume', xanchor: 'center', yanchor: 'botton', showarrow: false}, ";
    }
    $x =~ s/, $/\]/g;
    $y =~ s/, $/\]/g;
    $text =~ s/, $/\],/g;
    $annotations =~ s/, $/\];/g;

    my $str = "var lateness_volume_$region2 = {\n\t$x,\n\t$y,\n\ntype: 'bar',\n\ttext: $text\n};\n";
    $str .= "$annotations\n";
    $str .= "var data_lateness_volume_$region2 = [lateness_volume_$region2];\n";
    $str .= "var layout_lateness_volume_$region2 = {\n";
    $str .= "\ttitle: 'lateness per Volume (Ton.RW)',\n";
    $str .= "\tannotations: annotations_lateness_volume_$region2,\n";
    $str .= "showlegend: false,\n";
    $str .= "xaxis: { type: 'category', title: 'lateness (days)' },\n";
    $str .= "yaxis: { title: 'Volume (Ton.RW) $region' },\n";
    $str .= "};\n";
    $str .= "Plotly.plot('lateness_volume_$region2', data_lateness_volume_$region2, layout_lateness_volume_$region2, {showSendToCloud: true, responsive: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub lateness_fields_region
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $region = $_[3];
    my $query = "SELECT DISTINCT t1.lateness, COUNT(DISTINCT t1.field) FROM homresult as t1, fieldhom as t2 where t1.plantnumber=? and t1.plant not like '\%SPAIN\%' and t1.tracking_number = t2.lot and t2.region=? GROUP BY lateness ORDER BY lateness";
    my $sth = $dbh->prepare($query);
    $sth->execute($plantNumber, $region);
    $sth->execute($plantNumber, $region);

    my $region2 = lc $region;
    $region2 =~ s/\s+/_/g;

    my $x = "x: [";
    my $y = "y: [";
    my $text = "[";
    my $annotations = "var annotations_lateness_fields_$region2 = [\n";

    while(my $line = $sth->fetchrow_arrayref)
    {
        my $lateness = $line->[0];
        my $fields   = $line->[1];
        $x .= "$lateness, ";
        $y .= "$fields, ";
        $text .= "'$fields fields with lateness $lateness', ";

        $annotations .= "{ x: '$lateness', y: $fields + 5, text: '$fields', xanchor: 'center', yanchor: 'botton', showarrow: false}, ";
    }
    $x =~ s/, $/\]/g;
    $y =~ s/, $/\]/g;
    $text =~ s/, $/\],/g;
    $annotations =~ s/, $/\];/g;

    my $str = "var lateness_fields_$region2 = {\n\t$x,\n\t$y,\n\ntype: 'bar',\n\ttext: $text\n};\n";
    $str .= "$annotations\n";
    $str .= "var data_lateness_fields_$region2 = [lateness_fields_$region2];\n";
    $str .= "var layout_lateness_fields_$region2 = {\n";
    $str .= "\ttitle: 'lateness per # of fields',\n";
    $str .= "\tannotations: annotations_lateness_fields_$region2,\n";
    $str .= "showlegend: false,\n";
    $str .= "xaxis: { type: 'category', title: 'lateness (days)' },\n";
    $str .= "yaxis: { title: '# of fields $region' },\n";
    $str .= "};\n";
    $str .= "Plotly.plot('lateness_fields_$region2', data_lateness_fields_$region2, layout_lateness_fields_$region2, {showSendToCloud: true, responsive: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#



#-----------------------------------------------------------------------------#
sub volume_per_day_stack_region
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $region = $_[3];
    my $query = "select distinct t1.harv_date, t1.variety, sum(t1.tonrw_harv) as total FROM homresult as t1, fieldhom as t2 where t1.plantnumber=? and plant not like '\%SPAIN\%' and t1.tracking_number = t2.lot and t2.region=? GROUP BY t1.harv_date, t1.variety order by t1.harv_date, t1.variety";
    my $sth = $dbh->prepare($query);
    $sth->execute($plantNumber, $region);

    my $region2 = lc $region;
    $region2 =~ s/\s+/_/g;

    my %hHybridharv_date = ();
    while(my ($harv_date, $hybrid, $volume) = $sth->fetchrow)
    {
        $hybrid =~ s/ STE//g;
        $hybrid =~ s/-/_/g;
        $hHybridharv_date{$hybrid}{$harv_date} = $volume;
    }

    my $str = "";
    my @data = ();

    foreach my $hybrid (sort keys %hHybridharv_date)
    {
        my $x = "x: [";
        my $y = "y: [";

        foreach my $date (sort keys %{$hHybridharv_date{$hybrid}})
        {
            my $volume = $hHybridharv_date{$hybrid}{$date};
            $x .= "'$date', ";
            $y .= "$volume, ";
        }
        $x =~ s/, $/\]/g;
        $y =~ s/, $/\]/g;

        $str .= "var trace_vol_$region2\_$hybrid = {\n";
        $str .= "\t$x,\n";
        $str .= "\t$y,\n";
        $str .= "\tname: '$hybrid',\n",
        $str .= "\ttype: 'bar'\n";
        $str .= "};\n\n";

        push @data, "trace_vol_$region2\_$hybrid";
    }

    $str .= "\nvar data_volume_per_day_stack_$region2 = [";
    for (@data)
    {
        $str .= "$_, ";
    }
    $str =~ s/, $/\];/g;
    $str .= "\n\n";
    $str .= "var layout_volume_per_day_stack_$region2 = {barmode: 'stack'};\n";
    $str .= "Plotly.plot('expected_volume_per_day_$region2', data_volume_per_day_stack_$region2, layout_volume_per_day_stack_$region2, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub hybrids_per_day_stack_region
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $region = $_[3];
    my $query = "select distinct t1.harv_date, t1.variety from homresult as t1, fieldhom as t2 where t1.plantnumber=? and t1.plant not like '\%SPAIN\%' and t1.tracking_number = t2.lot and t2.region=? order by harv_date, variety";
    my $sth = $dbh->prepare($query);
    $sth->execute($plantNumber, $region);

    my $region2 = lc $region;
    $region2 =~ s/\s+/_/g;

    my %hHybridharv_date = ();
    while(my ($harv_date, $hybrid) = $sth->fetchrow)
    {
        $hybrid =~ s/ STE//g;
        $hybrid =~ s/-/_/g;
        $hHybridharv_date{$hybrid}{$harv_date} = 1;
    }

    my $str = "";
    my @data = ();

    foreach my $hybrid (sort keys %hHybridharv_date)
    {
        my $x = "x: [";
        my $y = "y: [";

        foreach my $date (sort keys %{$hHybridharv_date{$hybrid}})
        {
            $x .= "'$date', ";
            $y .= "1, ";
        }
        $x =~ s/, $/\]/g;
        $y =~ s/, $/\]/g;

        $str .= "var trace_$region2\_$hybrid = {\n";
        $str .= "\t$x,\n";
        $str .= "\t$y,\n";
        $str .= "\tname: '$hybrid',\n",
        $str .= "\ttype: 'bar'\n";
        $str .= "};\n\n";

        push @data, "trace_$region2\_$hybrid";
    }

    $str .= "\nvar data_hybrids_per_day_stack_$region2 = [";
    for (@data)
    {
        $str .= "$_, ";
    }
    $str =~ s/, $/\];/g;
    $str .= "\n\n";
    $str .= "var layout_hybrids_per_day_stack_$region2 = {barmode: 'stack'};\n";
    $str .= "Plotly.plot('hybrids_per_day_$region2', data_hybrids_per_day_stack_$region2, layout_hybrids_per_day_stack_$region2, {showSendToCloud: true});\n";
    return $str;
}
#-----------------------------------------------------------------------------#
sub get_fields_harvested
{
    my $dbh = $_[0];
    my $plant = $_[1];
    my $plantNumber = $_[2];
    my $query = 'select "pa_feature_id", "pa_requirementtrackingnumber", "ACHDT" from scoutdata_v2 where "ACHDT" is not null';
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my %hash = ();
    while(my ($entity_id, $tracking_number, $actual_harvest_date) = $sth->fetchrow)
    {
        next if not length $tracking_number;
        my $key = $tracking_number . "_" . $entity_id;
        $hash{$key} = $actual_harvest_date;
    }
    $sth->finish;
    return \%hash;
}
#-----------------------------------------------------------------------------#

1;
