package t::helper;

use HTTP::Request;
use JSON qw/to_json
            from_json/;

use base 'Exporter';
our @EXPORT = qw/
	GET PUT POST PATCH DELETE
	response
/;

sub GET {
	my ($url, $headers) = @_;
	return HTTP::Request->new(GET => $url, $headers || []);
}

sub PUT {
	my ($url, $object) = @_;
	return HTTP::Request->new(
		PUT => $url,
		[Content_Type => 'application/json',
		 Accept       => 'application/json'],
		to_json($object));
}

sub POST {
	my ($url, $object) = @_;
	return HTTP::Request->new(
		POST => $url,
		[Content_Type => 'application/json',
		 Accept       => 'application/json'],
		to_json($object));
}

sub PATCH {
	my ($url, $object) = @_;
	return HTTP::Request->new(
		PATCH => $url,
		[Content_Type => 'application/json',
		 Accept       => 'application/json'],
		to_json($object));
}

sub DELETE {
	my ($url, $headers) = @_;
	return HTTP::Request->new(DELETE => $url, $headers || []);
}

sub response {
	my ($r) = @_;
	return from_json($r->decoded_content);
}

1;
