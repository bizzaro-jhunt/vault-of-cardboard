package VCB::Format::CSV;
use strict;
use warnings;
use Text::CSV qw/csv/;
use VCB::Format;
use VCB::Format::Utils;
BEGIN { VCB::Format::register(10, __PACKAGE__); }

sub detect {
	my ($class, $s) = @_;
	if ($s =~ m/.+?,.+?,.+?/) {
		return 1;
	}
	return undef;
}

my %CONDITIONS = (
	'NEAR MINT' => 'NM',
	'MINT'      => 'M',
	'VERY GOOD' => 'VG',
	'GOOD'      => 'G',
);

sub parse {
	my ($class, $s) = @_;
	my @cards;

	for (@{ csv({ in => \$s, headers => "lc" }) }) {
		my $card = {};
		for my $f (qw/quantity qty n count/, '#') {
			next unless exists $_->{$f};
			$card->{quantity} = $_->{$f};
			last;
		}
		for my $f (qw/name title card/) {
			next unless exists $_->{$f};
			$card->{name} = $_->{$f};
			last;
		}
		for my $f (('set code')) {
			next unless exists $_->{$f};
			$card->{set} = uc($_->{$f});
			last;
		}
		for my $f (qw/condition cond quality/) {
			next unless exists $_->{$f};
			$card->{condition} = $CONDITIONS{uc($_->{$f})} || $_->{$f};
			last;
		}

		push @cards, $card;
	}

	return \@cards;
}

1;
