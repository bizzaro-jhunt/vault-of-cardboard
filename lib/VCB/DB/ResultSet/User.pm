package VCB::DB::ResultSet::User;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub authenticate {
	my ($class, $username, $password) = @_;

	my $user = $class->find({ account => $username });
	if ($user) {
		return $user->authenticate($password) ? $user : undef;

	} else {
		# FIXME: perform a dummy bcrypt op, to avoid timing-based account enumeration.
		#        without this 'extra' work, an attacker could fingerprint the system by
		#        brute-forcing login attempts (either single-source, or distributed)
		#        and observe relative timing to figure out which accounts were real,
		#        and which weren't -- the real accounts take longer to fail the auth.
		return undef;
	}
}

1;
