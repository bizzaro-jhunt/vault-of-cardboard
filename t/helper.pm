package t::helper;

use HTTP::Request;
use JSON qw/to_json
            from_json/;

use base 'Exporter';
our @EXPORT = qw/
	GET PUT POST PATCH DELETE
	response

	login
/;

my $SID;

sub r {
	my $req = HTTP::Request->new(@_);
	$req->header(Cookie => "vcb_sesh=$SID") if $SID;
	return $req;
}

sub GET {
	my ($url, $headers) = @_;
	return r(GET => $url, $headers || []);
}

sub PUT {
	my ($url, $object) = @_;
	return r(PUT => $url,
	         [Content_Type => 'application/json',
	          Accept       => 'application/json'],
	         to_json($object));
}

sub POST {
	my ($url, $object) = @_;
	return r(POST => $url,
	         [Content_Type => 'application/json',
	          Accept       => 'application/json'],
	         to_json($object));
}

sub PATCH {
	my ($url, $object) = @_;
	return r(PATCH => $url,
	         [Content_Type => 'application/json',
	          Accept       => 'application/json'],
	         to_json($object));
}

sub DELETE {
	my ($url, $headers) = @_;
	return r(DELETE => $url, $headers || []);
}

sub response {
	my ($r) = @_;
	my $h = $r->header('Set-Cookie');
	# vcb_sesh=xAxbnVEFareNebXbeDnalUejYGRmNQgOylJZMqgYoMmYxeoXwqIdosBGzkDinRPHO; Path=/; Expires=Sun, 29-Sep-2019 11:33:58 GMT; SameSite=Strict; HttpOnly
	$SID = $1 if $h =~ m/^vcb_sesh=(.*?);/;
	return from_json($r->decoded_content);
}

1;
