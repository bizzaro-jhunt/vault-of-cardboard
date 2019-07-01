package VCB::Format::Utils;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT = qw/lines/;

sub lines {
	my ($s) = @_;
	return grep { $_ && !m/^#/ } map { s/(^\s+|\s+$)//; $_ } split(/\n/, $s || '');
}

1;
