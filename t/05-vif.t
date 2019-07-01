#!perl
use strict;
use warnings;

use Test::More tests => 17;
use Test::NoWarnings;

use lib "lib";
use VCB::Format;

sub get_vif_from {
	my ($path) = @_;
	open my $fh, "<", "t/vif/$path"
		or die "t/vif/$path: $!\n";
	my $raw = do { local $/; <$fh> };
	close $fh;
	return $raw;
}

sub has_card {
	my ($cards, $q, $msg) = @_;
	for (@$cards) {
		#use Data::Dumper; print STDERR Dumper($_);
		my $k;
		$k = 'set';        next if $q->{$k} && (!exists($_->{$k}) || ($q->{$k} && $_->{$k} ne $q->{$k}));
		$k = 'name';       next if $q->{$k} && (!exists($_->{$k}) || ($q->{$k} && $_->{$k} ne $q->{$k}));
		$k = 'flags';      next if $q->{$k} && (!exists($_->{$k}) || ($q->{$k} && $_->{$k} ne $q->{$k}));
		$k = 'conditions'; next if $q->{$k} && (!exists($_->{$k}) || ($q->{$k} && $_->{$k} ne $q->{$k}));

		$k = 'quantity';   next if $q->{$k} && (!exists($_->{$k}) || ($q->{$k} && $_->{$k} != $q->{$k}));

		ok(1, $msg);
		return;
	}
	ok(0, $msg);
}

{
	my $vif = get_vif_from("simple.archidekt");
	ok(VCB::Format::Archidekt->detect($vif),
		"archidekt format should detect a simple Archidekt import");

	my $cards = VCB::Format::Archidekt->parse($vif);
	ok($cards, "archidekt format should be able to parse a simple Archidekt import");

	has_card $cards, { set => 'MBS', name => 'Darksteel Plate', quantity => 1 },
		"[autodetected] simple.archidekt includes [MBS] Darksteel Plate";
	has_card $cards, { set => 'C17', name => 'Skullclamp', quantity => 1 },
		"archidekt format parses all the way to the end";

	$cards = VCB::Format->parse($vif);
	ok($cards, "[autodetected] archidekt format should be able to parse a simple Archidekt import");

	has_card $cards, { set => 'MBS', name => 'Darksteel Plate', quantity => 1 },
		"[autodetected] simple.archidekt includes [MBS] Darksteel Plate";
	has_card $cards, { set => 'C17', name => 'Skullclamp', quantity => 1 },
		"[autodetected] archidekt format parses all the way to the end";
}

{
	my $vif = get_vif_from("goblin-horde.archidekt");
	ok(VCB::Format::Archidekt->detect($vif),
		"archidekt format should detect an export from Archidekt");

	my $cards = VCB::Format::Archidekt->parse($vif);
	ok($cards, "archidekt format should be able to parse an export from Archidekt");

	has_card $cards, { set => 'C17', name => 'Skullclamp', quantity => 1 },
		"goblin-horde.archidekt includes [C17] Skullclamp";
	has_card $cards, { set => 'C17', name => 'Path of Ancestry', quantity => 1 },
		"archidekt format parses cards without custom trailing metadata";
	has_card $cards, { set => 'KLD', name => "Smuggler's Copter", quantity => 1 },
		"archidekt format parses all the way to the end";

	$cards = VCB::Format->parse($vif);
	ok($cards, "[autodetected] archidekt format should be able to parse an export from Archidekt");

	has_card $cards, { set => 'C17', name => 'Skullclamp', quantity => 1 },
		"[autodetected] goblin-horde.archidekt includes [C17] Skullclamp";
	has_card $cards, { set => 'C17', name => 'Path of Ancestry', quantity => 1 },
		"[autodetected] archidekt format parses cards without custom trailing metadata";
	has_card $cards, { set => 'KLD', name => "Smuggler's Copter", quantity => 1 },
		"[autodetected] archidekt format parses all the way to the end";
}
