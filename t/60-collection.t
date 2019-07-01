#!perl
use Test::More tests => 13;
use Test::NoWarnings;
use Test::Deep;

use VCB::Test;

spin_app_ok;
use_cache_ok "t/cache/mirage";
login_ok urza => "mishra's factory";

ingest_ok 'MIR';
have_set 'MIR';

cmp_deeply timeline, [], "by default, a user's timeline should be empty";
buy_ok <<EOF;
4x  MIR Abyssal Hunter
20x MIR Swamp
EOF
cmp_deeply timeline, [
		superhashof({
			type => 'buy',
			card_gain   => 24,
			card_loss   => 0,
			unique_gain => 2,
			unique_loss => 0,
		})
	], "after a BUY, a user's timeline should have a single entry";



buy_ok <<EOF;
1x MIR Enlightened Tutor
1x MIR Mystical Tutor
1x MIR Worldly Tutor
EOF
cmp_deeply timeline, [
		superhashof({
			type => 'buy',
			card_gain   => 24,
			card_loss   => 0,
			unique_gain => 2,
			unique_loss => 0,
		}),
		superhashof({
			type        => 'buy',
			card_gain   => 3,
			card_loss   => 0,
			unique_gain => 3,
			unique_loss => 0,
		}),
	], "after a second BUY, a user's timeline should have two entries";



buy_ok <<EOF;
10x MIR Swamp
EOF
cmp_deeply timeline, [
		superhashof({
			type => 'buy',
			card_gain   => 24,
			card_loss   => 0,
			unique_gain => 2,
			unique_loss => 0,
		}),
		superhashof({
			type        => 'buy',
			card_gain   => 3,
			card_loss   => 0,
			unique_gain => 3,
			unique_loss => 0,
		}),
		superhashof({
			type        => 'buy',
			card_gain   => 10,
			card_loss   => 0,
			unique_gain => 1,
			unique_loss => 0,
		}),
	], "unique_gain doesn't reflect the collection as whole, only the BUY op";
