use strict;
use warnings;
use Plack::Builder;
use VCB::API;

builder {
	enable "Plack::Middleware::Static",
		path => qr{^/(fonts|img|js|css|index\.html|vcb\.png)\b},
		root => '/app/public';
	VCB::API->to_app;
};
