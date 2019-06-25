package VCB::Format::Standard;
use strict;
use warnings;

use VCB::Format;
use VCB::Format::Utils;
use VCB::Format::LineParser;
BEGIN { VCB::Format::register(10, __PACKAGE__); }

=cut

The Standard VCB format is line-based, where:

  1) Lines are separated by bare line feeds (\n, ASCII 0x10)
  2) Blank lines are ignored
  3) Leading and trailing whitespace (space or horizontal tab) are ignored
  4) Each non-blank line represents one "quantity-set" of cards
  5) Each non-blank line is comprised of between X and Y tokens, plus a name

Example:

   1 DOM F NM Name of the card
   ^ ^   ^ ^  ^
   | |   | |  |
   | |   | |  `---- full oracle name of card, with interior whitespace
   | |   | |
   | |   | `------- (OPTIONAL) condition of card, one of:
   | |   |            - M  : mint
   | |   |            - NM : near mint
   | |   |            - EX : excellent
   | |   |            - VG : very good
   | |   |            - G  : good
   | |   |            - P  : poor
   | |   |
   | |   `--------- (OPTIONAL) flags, any combination of the following:
   | |                - F (foil)
   | |
   | `------------- set code
   |
   `--------------- quantity of cards

Because no card name consists solely of uppercase characters, and since
the flags and condition values do not overlap, it is unambiguous to allow
those two fields to be optional.

The quantity can be specified as a number (1) or a number-x (1x).
This also is unambiguous.

=cut

sub detect {
	my ($class, $s) = @_;

	for (lines($s)) {
		return undef unless m/^\d+x?\s+(F\s+)?((M|NM|VG|EX|G|P|U)\s+)?([A-Za-z0-9]{3,})/;
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

		my @tok = split /\s+/;
		(my $quantity = shift @tok) =~ s/x$//i;
		$quantity =~ m/^\d+/
			or die "bad quantity '$quantity'\n";

		my $set = '';
		if ($tok[0] =~ m/^[A-Z0-9]{2,}$/) {
			$set = shift @tok;
		}

		my $flags = '';
		my $cond  = '';

		my $next;
		$next = shift @tok;
		if ($next =~ m/^[F]+$/i) {
			$flags = uc $next;
			$next = shift @tok;
		}
		if ($next =~ m/^(M|NM|VG|EX|G|P|U)$/i) {
			$cond = $next;
			$next = shift @tok;
		}

		unshift @tok, $next;
		my $name = join(' ', @tok);

		if (!$name && $set) {
			$name = $set;
			$set = '';
		}

		push @cards, {
			_parser   => $line,
			quantity  => $quantity,
			set       => $set,
			flags     => $flags,
			condition => $cond,
			name      => $name,
		};
	}

	return \@cards;
}

sub format1 {
	my ($card) = @_;
	my $l = sprintf("%dx %s %s %s %s",
		$card->{quantity},
		$card->{set},
		$card->{flags}     || '',
		$card->{condition} || '',
		$card->{name});
	$l =~ s/\s+/ /g;
	return "$l\n";
}

sub format {
	my ($class, $cards) = @_;
	return join '', map { format1($_) } @$cards;
}

sub print1 {
	my ($class, $fh, $card) = @_;
	print $fh format1($card);
}

1;
