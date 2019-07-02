#!perl
use Test::More tests => 14;
use Test::NoWarnings;
use Test::Deep;

use VCB::Test;

spin_app_ok;
use_cache_ok "t/cache/mirage";
login_ok urza => "mishra's factory";

ingest_ok 'MIR';
have_set 'MIR';

dont_have_deck "mirages";
import_deck {
	code   => 'mirages',
	name   => "Mirages, Mirages Everywhere!",
	format => "custom",
}, <<EOF;
# lands
20x MIR Island
EOF
have_deck "mirages";
cmp_deeply deck('mirages'), superhashof({
	code  => 'mirages',
	name  => 'Mirages, Mirages Everywhere!',
	cover => '',
}), "mirages deck shold match our expectations";

update_deck mirages => {
		notes  => "This was my first ever mono-blue deck, in my first Magic expansion set, Mirage!\n\n",
		cover  => "MIR Sapphire Charm",
	}, <<EOF;
# lands
20x MIR Island

# spells
 4x MIR Boomerang
 4x MIR Meddle
 4x MIR Sapphire Charm
 2x MIR Memory Lapse
 2x MIR Mystical Tutor
 2x MIR Political Trickery
 2x MIR Teferi's Isle

# creatures
 4x MIR Coral Fighters
 4x MIR Suq'Ata Firewalker
 3x MIR Bay Falcon
 2x MIR Dream Fighterr
 2x MIR Kukemssa Pirates
 2x MIR Kukemssa Serpent
 1x MIR Cerulean Wyvern
 1x MIR Mist Dragon
 1x MIR Sandbar Crocodile
EOF
cmp_deeply deck('mirages'), superhashof({
	code  => 'mirages',
	name  => 'Mirages, Mirages Everywhere!',
	cover => 'MIR Sapphire Charm',
}), "mirages deck shold match our expectation (after update)";

delete_deck 'mirages';
dont_have_deck 'mirages', "The 'mirages' deck should be missing after it is deleted";
