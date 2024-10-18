use FindBin;
use Plack::Middleware::CrossOrigin;
use Plack::Builder;
use lib "$FindBin::Bin/../lib";
use App;



# Allow any WebDAV or standard HTTP request from any location.
builder {
    enable 'CrossOrigin', 
    origins => '*', 
    headers => '*',
    methods => ['GET', 'POST', 'HEAD', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'], 
    max_age => 60*60*24*30;
    App->to_app;
};
