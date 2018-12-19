use strict;
use warnings;
use Plack::Builder;
use VCB::API;

builder {
	enable "Plack::Middleware::Static",
		path => qr{(^/(fonts|img|js|css)/)|(\.(html|png|jpg)$)},
		root => '/app/public';
	VCB::API->to_app;
};
