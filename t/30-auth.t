#!perl
use strict;
use warnings;

BEGIN {
	unlink("test.db");
	$ENV{DANCER_ENVIRONMENT} = 'test';

	$ENV{VCB_FAILSAFE_USERNAME} = 'urza';
	$ENV{VCB_FAILSAFE_PASSWORD} = '$2a$12$gVWeTxwtfA5rpM.rj3bQqO$db1ab87bed231995c2b0c275379bb3bafcd12cb4b97474';
	#                              ^^ is "mishra's factory" (default failsafe password)
};

use lib ".";
use Test::More tests => 24;
use Test::NoWarnings;
use t::helper;
use Plack::Test;
use Data::Dumper;

use lib "lib";
use VCB::API;

my ($A, $R);
$A = Plack::Test->create( VCB::API->to_app );

##
##   Verify that we are (initially) logged out with a WHOAMI request
##
$R = $A->request(GET '/v/whoami');
ok $R->is_success, 'should be able to request WHOAMI before a login';
$R = response($R);
ok(!$R->{$_}, "{$_} should not be found in request to anonymous WHOAMI")
	for qw(id account display);


##
##   Log in (incorrectly) with bad user credentials
##
$R = $A->request(POST '/v/login', { username => 'urza',
                                    password => "mightstone" });
ok !$R->is_success, 'should not be able to log in with incorrect credentials';
$R = response($R);
ok !$R->{ok}, "/v/login endpoint does not respond 'ok' on failed login";
like $R->{error}, qr/invalid username or password/i,
	"/v/login endpoints gives back a proper error response to a failed login";


##
##   Verify that we are logged out (still) with a WHOAMI request
##
$R = $A->request(GET '/v/whoami');
ok $R->is_success, 'should be able to request WHOAMI after a failed login';
$R = response($R);
ok(!$R->{$_}, "{$_} should not be found in request to anonymous WHOAMI")
	for qw(id account display);


##
##   Log in with correct credentials
##
$R = $A->request(POST '/v/login', { username => 'urza',
                                    password => "mishra's factory" });
ok $R->is_success, 'should be able to log in with correct credentials';
$R = response($R);
like $R->{ok}, qr/authenticated successfully/i,
	"/v/login endpoint gives back a proper response to a successful login";


##
##   Verify that we are logged in with a WHOAMI request
##
$R = $A->request(GET '/v/whoami');
ok $R->is_success, 'should be able to request WHOAMI after a login';
$R = response($R);
ok($R->{$_}, "{$_} should be found in request to authenticated WHOAMI")
	for qw(id account display);


##
##   Log out of Vault of Cardboard
##
$R = $A->request(POST '/v/logout');
ok $R->is_success, "logout should always succeed";
$R = response($R);
like $R->{ok}, qr/logged out/i,
	"/v/logout endpoint gives back a proper response to a successful logout";


##
##   Verify that we are logged out with a WHOAMI request
##
$R = $A->request(GET '/v/whoami');
ok $R->is_success, 'should be able to request WHOAMI after a logout';
$R = response($R);
ok(!$R->{$_}, "{$_} should not be found in request to anonymous WHOAMI")
	for qw(id account display);
