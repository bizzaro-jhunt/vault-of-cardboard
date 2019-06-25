package VCB::Format;
use strict;
use warnings;

my @FORMATS;
sub register {
	my ($priority, $package) = @_;
	push @FORMATS, [] while @FORMATS < $priority + 1;
	push @{ $FORMATS[$priority] }, $package;
}

use VCB::Format::Archidekt;
use VCB::Format::CSV;
use VCB::Format::Standard;

sub parse {
	my ($class, $s) = @_;

	for (@FORMATS) {
		for (@{$_}) {
			return $_->parse($s) if $_->detect($s);
		}
	}

	die "unrecognized card list format\n";
}

1;
