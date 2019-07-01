#!perl
use strict;
use warnings;

BEGIN {
	$ENV{VCB_FAILSAFE_USERNAME} = 'urza';
	$ENV{VCB_FAILSAFE_PASSWORD} = '$2a$12$gVWeTxwtfA5rpM.rj3bQqO$db1ab87bed231995c2b0c275379bb3bafcd12cb4b97474';

	$ENV{DANCER_ENVIRONMENT} = 'test';
	unlink("test.db");
};

use lib ".";
use Test::More tests => 11;
use Test::NoWarnings;
use t::helper;
use Plack::Test;
use Data::Dumper;

use lib "lib";
use VCB::API;

my ($A, $R);
diag "setting up vault of cardboard test instance...";
$A = Plack::Test->create( VCB::API->to_app );

diag "performing pre-authentication WHOAMI request (/v/whoami)";
$R = $A->request(GET '/v/whoami');
ok $R->is_success, 'should be able to request WHOAMI before a login';
$R = response($R);
ok(!$R->{$_}, "{$_} should not be found in request to anonymous WHOAMI")
	for qw(id account display);


diag "performing authentication request (/v/login)";
$R = $A->request(POST '/v/login', { username => 'urza',
                                    password => "mishra's factory" });
ok $R->is_success, 'should be able to log in successfully';
$R = response($R);
like $R->{ok}, qr/authenticated successfully/i,
	"/v/login endpoint gives back a proper response to a successful login";


diag "performing post-authentication WHOAMI request (/v/whoami)";
$R = $A->request(GET '/v/whoami');
ok $R->is_success, 'should be able to request WHOAMI after a login';
$R = response($R);
ok($R->{$_}, "{$_} should be found in request to authenticated WHOAMI")
	for qw(id account display);

diag "final (meta-)tests";
