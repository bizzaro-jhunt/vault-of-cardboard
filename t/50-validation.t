#!perl
use Test::More tests => 10;
use Test::NoWarnings;

use VCB::Test;

spin_app_ok;
use_cache_ok "t/cache/mirage";
login_ok urza => "mishra's factory";

dont_have_set 'MIR';

validate_fails <<EOF, "should fail to validate a MIR-based import";
1x MIR Abyssal Hunter
EOF

ingest_ok 'MIR';
have_set 'MIR';

validate_ok <<EOF, "should validate MIR-base import after ingesting [MIR]";
1x MIR Abyssal Hunter
EOF

validate_fails <<EOF, "should fail with a horribly mangled import";
my magic cards
EOF
