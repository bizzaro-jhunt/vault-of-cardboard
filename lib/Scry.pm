package Scry;
use strict;
use warnings;

use LWP::UserAgent qw//;
use Time::HiRes    qw/gettimeofday
                      usleep/;
use JSON::PP       qw/decode_json/;

use constant DELAY => 0.125; # in seconds

sub new {
	my ($class) = @_;

	my $ua = LWP::UserAgent->new(
		agent    => 'scry/0.1-alpha4',
		ssl_opts => { verify_hostname => 0 },
	);

	return bless({
		ua   => $ua,
		last => 0,
	}, $class);
}

sub pause {
	my ($self) = @_;

	my $now = gettimeofday();
	my $min = $self->{last} + DELAY;

	#print "pause: now=$now\n";
	#print "       min=$min\n";
	#print "      last=$self->{last}\n";
	#print "      diff=".($min - $now)."\n\n";

	printf "scryfall: sleeping for %d ms...\n", 1000 * ($min - $now)
		if $now < $min;
	usleep(1000 * 1000 * ($min - $now))
		if $now < $min;

	$self->{last} = $now;
}

sub url {
	my ($uri) = @_;
	$uri = "https://api.scryfall.com$uri" if $uri =~ m{^/};
	return $uri;
}

sub get1 {
	my ($self, $uri) = @_;
	$self->pause;

	my $res = $self->{ua}->get(url($uri));
	if (!$res->is_success) {
		return wantarray? (undef, $res->status_line) : undef;
	}

	my $data = decode_json($res->decoded_content);
	if (!$data) {
		return wantarray? (undef, $!) : undef;
	}

	return $data;
}

sub get {
	my ($self, $uri) = @_;

	my @l;
PAGE:
	while (1) {
		my ($data, $err) = $self->get1($uri);
		if (!$data) {
			return wantarray? (undef, $err) : undef;
		}
		@l = (@l, @{$data->{data}});
		last PAGE unless $data->{has_more};
		$uri = $data->{next_page};
	}

	return \@l;
}

1;
