use strict;
use warnings;
use Plack::Builder;
use VOC::API;

builder {
	enable "Plack::Middleware::Static",
		path => qr{^/(fonts|img|js|css|index\.html|voc\.png)\b},
		root => '/app/public';
	VOC::API->to_app;
};
