package VCB::Format;
use strict;
use warnings;

my @FORMATS;
sub register {
	push @FORMATS, $_[0];
}

use VCB::Format::Archidekt;
use VCB::Format::CSV;
use VCB::Format::Standard;

sub parse {
	my ($class, $s) = @_;

	for (@FORMATS) {
		return $_->parse($s) if $_->detect($s);
	}

	die "unrecognized card list format\n";
}

1;
