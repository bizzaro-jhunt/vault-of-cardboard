package VCB::Format::Archidekt;
use strict;
use warnings;

use VCB::Format;
use VCB::Format::Utils;
BEGIN { VCB::Format::register(0, __PACKAGE__); }

=cut

The Archidekt deck export format is line-based, and looks
something like this:

    4x Adventurous Impulse (dom)
    2x Affectionate Indrik (grn)
    2x Ambuscade (hou)
    1x Cobbled Wings (xln)
    4x Colossal Dreadmaw (a25)
    1x Druid of the Cowl (aer)
    1x Fleetfeather Sandals (ths)
    20x Forest (rix)

The set code is lowercase, in parentheses after the name.
Card condition is unspecified or untracked, and Foil-iness
is not currently handled.

There are a number of other nuances in the format, including
categories, labels, etc.  These are not yet supported.

=cut

sub detect {
	my ($class, $s) = @_;

	for (lines($s)) {
		return undef unless m/^\d+x?\s+(.*)\s+\([A-Za-z0-9]{3,}\).*$/;
	}
	return 1;
}

sub parse {
	my ($class, $s) = @_;
	my @cards;

	my $parser = VCB::Format::LineParser->for($s);
	while (my $line = $parser->next()) {
		local $_ = $line->{text};
		s/^\s+|\s+$//;
		s/\s*#.*//;
		next unless $_;

		die "malformed line: '$_'\n"
			unless m/^(\d+)x?\s+(.*)\s+\(([A-Za-z0-9]{3,})\).*$/;

		push @cards, {
			_parser   => $line,
			quantity  => $1+0,
			set       => uc($3),
			flags     => '',
			condition => '',
			name      => $2,
		};
	}

	return \@cards;
}

1;
