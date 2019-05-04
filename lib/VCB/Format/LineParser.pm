package VCB::Format::LineParser;

sub for {
	my ($class, $src) = @_;
	bless({
		line => 1,
		idx  => 0,
		src  => $src,
		len  => length($src),
	}, $class);
}

sub next {
	my ($self) = @_;

	my $i = $self->{idx};

	while ($i < $self->{len}) {
		my $c = substr($self->{src}, $i, 1);
		if ($c eq "\r" || $c eq "\n") {
			my $line = {
				text => substr($self->{src}, $self->{idx}, $i - $self->{idx}),
				line => $self->{line}++,
			};
			$self->{idx} = ++$i;
			if ($c eq "\r" && substr($self->{src}, $i, 1) eq "\n") {
				$self->{idx}++;
			}
			return $line;
		}
		$i++;
	}

	if ($self->{idx} >= $self->{len}) {
		return undef; # no more lines...
	}

	my $line = {
		text => substr($self->{src}, $self->{idx}),
		line => $self->{line}++,
	};
	$self->{idx} = $self->{len};
	return $line;
}

sub all {
	my ($class, $src) = @_;
	my $p = $class->for($src);
	my @lines;
	while (my $line = $p->next()) {
		push @lines, $line;
	}
	return @lines;
}

1;
