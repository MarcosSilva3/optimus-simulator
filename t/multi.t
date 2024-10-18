use strict;
use warnings;
use 5.010;

use Test::More tests => 3;
use Plack::Test;
use HTTP::Request::Common qw(GET);
use FindBin;

my $app = do "$FindBin::Bin/../bin/app.psgi";
is( ref $app, 'CODE', 'Got app' );
my $test = Plack::Test->create($app);

subtest main => sub {
    plan tests => 3;
    my $res = $test->request( GET '/' );
    ok( $res->is_success, '[GET /] successful' );
    is( $res->header('Content-type'), 'text/html; charset=UTF-8' );
    is( $res->content, 'Hello world from module <a href="/other">Other page</a>', 'Content looks ok' );
};


subtest other => sub {
    plan tests => 3;
    my $res = $test->request( GET '/other' );
    ok( $res->is_success, '[GET /other] successful' );
    is( $res->header('Content-type'), 'text/html; charset=UTF-8' );
    is( $res->content, 'Other page', 'Content looks ok' );
};