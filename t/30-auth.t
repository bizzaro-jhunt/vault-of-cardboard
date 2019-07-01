#!perl
use Test::More tests => 9;
use Test::NoWarnings;

use VCB::Test;

spin_app_ok;
iam_anonymous "we should be initially logged out";

login_fails "urza", "mightstone";
iam_anonymous "we are still logged out after a failed login";

login_ok "urza", "mishra's factory";
iam { display => 'urza' }, "we should be logged in now";

logout_ok;
iam_anonymous "we are logged out after we logout";
