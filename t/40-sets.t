#!perl
use Test::More tests => 8;
use Test::NoWarnings;

use VCB::Test;

spin_app_ok;
login_ok urza => "mishra's factory";

use_cache_ok "t/cache/mirage";
dont_have_set 'MIR';
ingest_ok 'MIR';
have_set 'MIR';
set_is MIR => { size => 350 }, "[MIR] should have 350 cards";
