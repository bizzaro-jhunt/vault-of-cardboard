#!perl
use strict;
use warnings;

use Test::More;
use t::helper;
use lib "lib";
use Plack::Test;

use Data::Dumper;

use VCB::API;

my ($A, $R);
diag "setting up vault of cardboard test instance...";
$A = Plack::Test->create( VCB::API->to_app );

diag "performing pre-authentication WHOAMI request (/v/whoami)";
$R = $A->request(GET '/v/whoami');
ok $R->is_success, 'should be able to request WHOAMI before a login';
$R = response($R);
ok(!$R->{$_}, "{$_} should not be found in request to anonymouse WHOAMI")
	for qw(id account display);


diag "performing authentication request (/v/login)";
$R = $A->request(POST '/v/login', { username => 'urza',
                                    password => 'admin' });
ok $R->is_success, 'should be able to log in successfully';
$R = response($R);
like $R->{ok}, qr/authenticated successfully/i,
	"/v/login endpoint gives back a proper response to a successful login";
my $sid = $R->{user}{session};


diag "performing post-authentication WHOAMI request (/v/whoami)";
$R = $A->request(GET '/v/whoami', [Cookie => sprintf("vcb_sesh=%s", $sid)]);
ok $R->is_success, 'should be able to request WHOAMI after a login';
$R = response($R);
ok($R->{$_}, "{$_} should be found in request to anonymouse WHOAMI")
	for qw(id account display);


done_testing;
