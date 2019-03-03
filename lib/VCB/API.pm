package VCB::API;
use strict;
use warnings;

use POSIX qw/strftime/;
use Data::Dumper;
use Data::UUID;
use File::Find;
use Cwd qw/cwd/;
use MIME::Base64 qw/decode_base64/;
use Net::Amazon::S3;
use JSON::MaybeXS qw/to_json from_json/;

use VCB::Format;
use VCB::Format::Standard;
use Scry;

use VCB::DB::Setup;

use Dancer2;
use Dancer2::Plugin::DBIC;

set serializer => 'JSON';
set static_handler => true;
config->{vcb}{imgroot}    ||= '/img';
config->{vcb}{datroot}    ||= cwd.'/dat';
config->{vcb}{cacheroot}  ||= cwd.'/cache';
config->{vcb}{cachefor}   ||= 1;
config->{vcb}{s3}{aki}    ||= $ENV{S3_AKI};
config->{vcb}{s3}{key}    ||= $ENV{S3_KEY};
config->{vcb}{s3}{bucket} ||= $ENV{S3_BUCKET} || 'vault-of-cardboard';
config->{vcb}{s3}{region} ||= $ENV{S3_REGION} || 'us-east-1';

delete $ENV{S3_KEY}; # potentially sensitive

for my $var (sort keys %ENV) {
	print STDERR "ENV> $var = '$ENV{$var}'\n";
}

if (POSIX::getpid() == 1) {
	print STDERR "installing signal handlers...\n";
	$SIG{TERM} = $SIG{INT} = sub { exit 0 };
}

my %SESH;

#########################################################################

my $DATFILE;
sub datpath {
	return config->{vcb}{datroot} unless @_;

	$DATFILE = join('/', config->{vcb}{datroot}, @_);
	return $DATFILE;
}

my $CACHEFILE;
sub cachepath {
	return config->{vcb}{cacheroot} unless @_;

	$CACHEFILE = join('/', config->{vcb}{cacheroot}, @_);
	return $CACHEFILE;
}

sub authn {
	my $c = cookies->{vcb_sesh};
	return $c ? $SESH{$c->value} : undef;
}

sub M {
	my ($model) = @_;
	return schema('default')->resultset($model);
}

my $UUID = Data::UUID->new;
sub uuidgen {
	return lc($UUID->to_string($UUID->create));
}
sub randstr {
	my ($len) = @_; $len ||= 22;
	my @alpha = ("A".."Z", "a".."z");
	my $pw; $pw .= $alpha[rand @alpha] for 0..$len;
	return $pw;
}

sub rarity {
	my %convert = (
		m => 'mythic',    mythic   => 'mythic',
		r => 'rare',      rare     => 'rare',
		c => 'common',    common   => 'common',
		u => 'uncommon',  uncommon => 'uncommon',
	);
	return $convert{lc($_[0])} || $_[0];
}

sub backfill_image {
	my ($ua, $bucket, $ours, $theirs, $msg, $force) = @_;
	if ($force || !$bucket->head_key($ours)) {
		warn "backfilling image for $msg...\n";
		my $res = $ua->get($theirs);
		if (!$res->is_success) {
			warn "failed to retrieve card face $msg '$theirs': ".$res->status_line."\n";
			return undef;
		}
		$bucket->add_key($ours, $res->decoded_content);
	}
	$bucket->set_acl({ acl_short => 'public-read', key => $ours });
	return 1;
}

#########################################################################

VCB::DB::Setup->migrate(config->{plugins}{DBIC}{default}{dsn});

if (M('User')->count == 0 && $ENV{VCB_FAILSAFE_USERNAME} && $ENV{VCB_FAILSAFE_PASSWORD}) {
	my $admin = M('User')->create({
		id        => uuidgen(),
		account   => $ENV{VCB_FAILSAFE_USERNAME},
		pwhash    => $ENV{VCB_FAILSAFE_PASSWORD},
		display   => $ENV{VCB_FAILSAFE_USERNAME},
		joined_at => POSIX::mktime(0, 0, 0, 5, 7, 93), # Limited Alpha release date...
		admin     => 1,
		active    => 1,
	}) or die "failed to create failsafe account: $!\n";
	$admin->collections->create({
		id        => uuidgen(),
		main      => 1,
		type      => 'collection',
	}) or die "failed to create primary collection for failsafe account: $!\n";
}

#########################################################################

get '/' => sub {
	send_file 'index.html';
};

get '/config.js' => sub {
	send_as
		plain => 'var $CONFIG = '.encode_json({
			imgroot => config->{vcb}{imgroot},
		}).';',
		{ content_type => 'application/javascript' };
};

get '/my/:type' => sub {
	my $user = authn or do {
		return "# you are not logged in...\n" if param('type') =~ m/\.vcb$/i;
		return {}                             if param('type') =~ m/\.json$/i;
		die "unrecognized type ".param('type')."\n";
	};
	redirect sprintf("/v/col/%s/%s/%s",
		$user->id, $user->primary_collection->id, param('type'));
};

sub validate_cards {
	my ($cards) = @_;

	my @errors;
	for my $card (@$cards) {
		my $print = M('Print')->search({
				name   => $card->{name},
				set_id => $card->{set}}
		) or do {
			push @errors, "card '$card->{name}' ($card->{set}) not found in printed cards table.";
			next;
		};

		$print->count > 0 or do {
			push @errors, "card '$card->{name}' ($card->{set}) not found in printed cards table.";
			next;
		};
	}

	return @errors;
}

post '/v/my/collection/validate' => sub {
	# input:
	# {
	#   "vcb" : "... (a VCB-formatted string) ..."
	# }

	# output:
	# {
	#   "ok" : "Collection validated."
	# }

	local $@;
	my @errors = eval { validate_cards(VCB::Format->parse(request->data->{vcb})); };
	if ($@) {
		warn "unable to parse input: $@\n";
		return { error => "Invalid VCB request payload." };
	}
	if (@errors) {
		return {
			error  => "Collection validation failed.",
			errors => \@errors,
		};
	}
	return { ok => "Collection validated." };
};

sub recache {
	my ($user, $col) = @_;
	my (%HAVE, %ALL);

	mkdir datpath();
	mkdir datpath($user->id);
	mkdir datpath($user->id, 'col');

	printf STDERR "caching collection '%s' [%s] for user '%s' [%s] in VCB format...\n",
		$col->name, $col->id, $user->account, $user->id;
	open my $fh, ">", datpath($user->id, "col/.new.vcb") or do {
		warn "unable to open $DATFILE: $!\n";
		return undef;
	};
	for my $card ($col->cards) {
		$HAVE{$card->print->set_id}{$card->print->name} = $card->quantity;
		VCB::Format::Standard->print1($fh, {
			name      => $card->print->name,
			set       => $card->print->set_id,
			condition => $card->quality,
			quantity  => $card->quantity,
			flags     => $card->flags,
		});
	}
	close $fh;
	rename datpath($user->id, "col/.new.vcb"),
	       datpath($user->id, "col", $user->primary_collection->id.".vcb");

	open $fh, ">", datpath($user->id, "col/.new.json") or do {
		warn "unable to open $DATFILE: $!\n";
		return undef;
	};
	print $fh encode_json(\%HAVE);
	close $fh;

	rename datpath($user->id, "col/.new.json"),
	       datpath($user->id, "col", $user->primary_collection->id.".json");

	return 1;
}

put '/my/collection' => sub {
	my $user = authn or return {
		"error" => "You are not logged in.",
		"authn" => "required"
	};

	# input: (a VCB-formatted string)

	# output:
	# {
	#   "ok" : "Collection updated."
	# }

	local $@;
	my $cards = eval { VCB::Format->parse(request->data->{vcb}); };
	if ($@) {
		warn "unable to parse input: $@\n";
		return { error => "Invalid VCB request payload." };
	}

	my @errors = validate_cards($cards);
	if (@errors) {
		return {
			error  => "Collection validation failed.",
			errors => \@errors,
		};
	}

	eval { $user->primary_collection->replace($cards); };
	if ($@) {
		warn "unable to update collection in database: $@\n";
		return { error => "Unable to update collection." };
	}

	recache($user, $user->primary_collection)
		or return { error => "Unable to update collection cache files." };

	return { ok => "Collection updated." };
};

get '/v/col/:user/:type' => sub {
	(my $ext = param('type')) =~ s/^.*?\.//;
	my $user = M('User')->find(param('user'));
	if ($user) {
		redirect sprintf("/v/col/%s/%s/%s",
			$user->id, $user->primary_collection->id, param('type'));
	} elsif ($ext eq 'vcb') {
		send_as plain => "# you don't have any cards yet...\n";
	} elsif ($ext eq 'json') {
		return {};
	}
};

get '/v/col/:user/:uuid/:type' => sub {
	# grab a collection, owned by a given user.
	#
	# these are statically-generated, so all we do here is validate
	# the requesting session against the given user UUID (:user)
	# and then translate that to a filesystem send call.

	(my $ext = param('type')) =~ s/^.*?\.//;
	my $file = datpath(param('user'), 'col', param('uuid').'.'.$ext);

	if (-f $file) {
		send_file $file, system_path => 1;
	} elsif ($ext eq 'vcb') {
		send_as plain => "# you don't have any cards yet...\n";
	} elsif ($ext eq 'json') {
		return {};
	}
};

#########################################################################
### authz

get '/v/whoami' => sub {
	my $user = authn;
	if ($user) {
		return {
			id      => $user->id,
			account => $user->account,
			display => $user->display,
		};
	} else {
		return {};
	}
};

post '/v/login' => sub {
	my $user = M('User')->authenticate(param('username'), param('password'));

	if ($user) {
		my $sid = randstr(64);
		$SESH{$sid} = $user;
		return {
			ok => "Authenticated successfully.",
			user => {
				id      => $user->id,
				account => $user->account,
				display => $user->display,
				session => $sid,
			},
		};
	}

	return { error => "Invalid username or password." };
};

post '/v/logout' => sub {
	delete $SESH{cookies->{vcb_sesh}};
	return { ok => "Logged out." };
};

#########################################################################
### user admin-y things

sub admin_authn {
	my $authorize = request_header 'Authorization';
	if (!$authorize) {
		status 401;
		response_header 'WWW-Authenticate' => 'Basic realm="Vault of Cardboard"';
		return undef;
	}

	if ($authorize !~ m/^Basic\s+(.*)/i) {
		status 401;
		response_header 'WWW-Authenticate' => 'Basic realm="Vault of Cardboard"';
		return undef;
	}

	my ($account, $password) = split ':', decode_base64($1), 2;
	my $user = M('User')->authenticate($account, $password);
	if (!$user || !$user->admin) {
		status 403;
		response_header 'WWW-Authenticate' => 'Basic realm="Vault of Cardboard"';
		return undef;
	}

	return $user;
}

sub admin_authn_failed {
	return { error => "Administrative authentication required." };
}

# create a new user
post '/v/admin/users' => sub {
	admin_authn or return admin_authn_failed;

	# input:
	# {
	#   "account" : "username",
	#   "display" : "User Name"
	# }

	# output:
	# {
	#   "ok"      : "Created user account",
	#   "created" : {
	#     "id"        : "ab9c5636-b05e-479f-a7c9-21b45f34ef66",
	#     "account"   : "username",
	#     "display"   : "User Name",
	#     "joined_at" : "2018-12-10 14:19:04",
	#     "active"    : true
	#   }
	# }

	my $pw = randstr();

	local $@;
	my $u = eval {
		M('User')->new({
			id        => uuidgen(),
			account   => param('account'),
			display   => param('display'),
			joined_at => time(),
			active    => 1,
		})->set_password($pw)
		  ->insert;
	};
	if ($@) {
		warn "failed to create user account '".param('account')."': ".$@."\n";
		return { error => "Unable to create account; check server logs for details." };
	}

	$u->collections->create({
		id   => uuidgen(),
		main => 1,
		type => 'collection',
	}) or do {
		warn "failed to create primary collection for user account".$u->account."\n";
		return { error => "Unable to create primary collection; check server logs for details." };
	};

	return {
		ok => "Created user account",
		created => {
			id        => $u->id,
			account   => $u->account,
			display   => $u->display,
			joined_at => strftime("%Y-%m-%d %H:%M:%S %z", gmtime($u->joined_at)),
			active    => $u->active,
			password  => $pw,
		},
	}
};

# retrieve user list
get '/v/admin/users' => sub {
	admin_authn or return admin_authn_failed;

	# input: (none)

	# output:
	# [
	#   {
	#      "id"        : "ab9c5636-b05e-479f-a7c9-21b45f34ef66",
	#      "account"   : "username",
	#      "joined_at" : "2018-12-10 14:19:04",
	#      "active"    : true
	#   }
	# ]

	[map {{
		id        => $_->id,
		account   => $_->account,
		joined_at => strftime("%Y-%m-%d %H:%M:%S %z", localtime($_->joined_at)),
		active    => $_->active,
	}} M('User')->search];
};

# retrieve user details
get '/v/admin/users/:uuid' => sub {
	admin_authn or return admin_authn_failed;

	# input: (none)

	# output:
	# {
	#    "id"        : "ab9c5636-b05e-479f-a7c9-21b45f34ef66",
	#    "account"   : "username",
	#    "joined_at" : "2018-12-10 14:19:04",
	#    "active"    : true
	# }
};

# update user details
put '/v/admin/users/:uuid' => sub {
	admin_authn or return admin_authn_failed;

	# input: (partial subset)
	# {
	#   "display" : "New Display Name",
	#   "account" : "new-username",
	#   "active"  : false
	# }

	# output:
	# {
	#   "ok"      : "Created user account",
	#   "updated" : {
	#     "id"        : "ab9c5636-b05e-479f-a7c9-21b45f34ef66",
	#     "display"   : "New Display Name",
	#     "account"   : "new-username",
	#     "joined_at" : "2018-12-10 14:19:04",
	#     "active"    : false
	#   },
	#   "fields": [
	#     "account",
	#     "active",
	#     "display"
	#   ]
	# }
};

#########################################################################
### collection admin-y things

# set the users primary collecton.
put '/v/admin/users/:uuid/collection' => sub {
	admin_authn or return admin_authn_failed;

	# input: (a VCB-formatted string)

	# output:
	# {
	#   "ok" : "Collection updated."
	# }

	my $user = M('User')->find(param('uuid'));
	if (!$user) {
		warn "unable to find user '".param('uuid')."'\n";
		return { error => "No such user." };
	}

	local $@;
	my $cards = eval { VCB::Format->parse(request->data->{vcb}); };
	if ($@) {
		warn "unable to parse input: $@\n";
		return { error => "Invalid VCB request payload." };
	}

	eval { $user->primary_collection->replace($cards); };
	if ($@) {
		warn "unable to update collection: $@\n";
		return { error => "Unable to update collection." };
	}

	recache($user, $user->primary_collection)
		or return { error => "Unable to update collection cache files." };

	return { ok => "Collection updated." };
};

# partial update to the users primary collection.
patch '/v/admin/users/:uuid/collection' => sub {
	admin_authn or return admin_authn_failed;

	# input: (a VCB-formatted string)

	# output:
	# {
	#   "ok": "Collection updated."
	# }
};

#########################################################################
### card set admin-y things

# ingest a set of cards, from upstream data
post '/v/admin/sets/:code/ingest' => sub {
	admin_authn or return admin_authn_failed;

	# input: (none)

	# output:
	# {
	#    "ok": "Set refreshed from upstream data."
	# }

	my $code = lc(param('code'));
	warn "ingesting set [$code]...\n";
	my $cache = cachepath("$code.set");
	if (-f $cache) {
		warn "checking if our cache file needs to be re-synced or not...\n";
		my $mtime = (stat($cache))[9];
		if (time - $mtime > config->{vcb}{cachefor} * 86400) {
			warn "cache file is ".((time - $mtime)/86400.0)." day(s) old (> ".config->{vcb}{cachefor}."); invalidating.\n";
			unlink $cache;
		}
	}
	if (! -f $cache) {
		mkdir cachepath();
		print "cache path '$cache' not found; pulling [$code] from scryfall...\n";
		open my $fh, ">", $cache or do {
			warn "failed to open cache file '$cache': $!\n";
			return { error => "failed to open cache file '$cache': $!" };
		};

		my $scry = Scry->new;
		my $set = $scry->get1("/sets/$code") or do {
			warn "failed to query ScryFall API for set [$code] data\n";
			return { "error" => "Failed to query Scryfall API." };
		};

		print "querying $set->{search_uri} ...\n";
		$set->{cards} = $scry->get($set->{search_uri}) or do {
			warn "failed to query ScryFall API for set [$code] card data\n";
			return { "error" => "Failed to query Scryfall API." };
		};

		print $fh encode_json($set);
		close $fh;
	}

	open my $fh, "<", $cache
		or return { error => "failed to read cache file: $!" };

	my $set = decode_json(do { local $/; <$fh> });
	close $fh;

	$set->{set} = uc($set->{set} || $code);
	my $s = M('Set')->find({ code => $set->{set} });
	if (!$s) {
		$s = M('Set')->create({
			code    => $set->{set},
			name    => $set->{name},
			release => 0, # temporary
		});
	}

	my %dates; # majority-wins release dating
	my %existing = map { $_->id => $_ } $s->prints;
	for my $card (@{$set->{cards}}) {
		$dates{$card->{released_at}}++;

		print "updating $set->{set} $card->{name}...\n";
		my $attrs = {
			id        => $card->{id},
			name      => $card->{name},
			oracle    => ($card->{card_faces} ? join("\n---\n", map { $_->{oracle_text} } @{$card->{card_faces}}) : $card->{oracle_text}) || '',
			type      => $card->{type_line},
			colnum    => $card->{collector_number},
			flavor    => ($card->{card_faces} ? join("\n---\n", map { $_->{flavor_text} } @{$card->{card_faces}}) : $card->{flavor_text}) || '',
			rarity    => substr($card->{rarity}, 0, 1),
			reprint   => !!$card->{reprint},
			reserved  => !!$card->{reserved},
			color     => join('', sort(@{$card->{color_identity}})),
			cmc       => $card->{cmc},
			mana      => ($card->{card_faces} ? $card->{card_faces}[0]{mana_cost} : $card->{mana_cost}) || '',
			artist    => $card->{artist},
			price     => $card->{usd} || 0,
			power     => $card->{power}     || '',
			toughness => $card->{toughness} || '',
			layout    => $card->{layout},
			legalese  => to_json($card->{legalities}),
		};
		my $rc = $existing{$card->{id}};
		if ($rc) {
			$rc->update($attrs);
			delete $existing{$card->{id}};
		} else {
			$s->prints->create($attrs);
		}
	}

	# whenever 60%+ of cards were released is
	# close enough to the set release date for me...
	for my $dated (keys %dates) {
		next if $dates{$dated} < 0.6 * scalar(@{$set->{cards}});
		$dated =~ s/-//g;
		$s->update({ release => $dated });
		last;
	}

	my @ids;
	push @ids, $_ for keys %existing;
	$s->prints->search({ id => \@ids })->delete
		if @ids;

	if (!!params->{faces}) {
		my $aki = config->{vcb}{s3}{aki};
		my $key = config->{vcb}{s3}{key};
		if (!$aki or !$key) {
			warn "card images refresh requested for set [$code]; but no S3 configuration found!\n";
			return { "error" => "Set refreshed from upstream data; but no S3 configuration was found for image refresh." };
		}

		my $pid = fork;
		if ($pid < 0) {
			warn "card image refresh requested for set [$code]; but background process fork failed!\n";
			return { "error" => "Set refreshed from upstream data; but the background process for image refresh failed to fork." };
		}

		if ($pid == 0) { # in child
			warn "connecting to s3 as $aki\n";
			my $s3 = Net::Amazon::S3->new({
				aws_access_key_id     => $aki,
				aws_secret_access_key => $key,
			});

			my $bucket = $s3->bucket(config->{vcb}{s3}{bucket});
			if (!$bucket || !$bucket->get_acl) {
				warn "card images refresh requested for set [$code]; but bucket '".config->{vcb}{s3}{bucket}."' not found!\n";
				exit(1);
			};

			my $ua = LWP::UserAgent->new(
				agent => 'mtgc-alpha/0.1',
				ssl_opts => { verify_hostname => 0 },
			);

			for my $card (@{$set->{cards}}) {
				if ($card->{layout} eq 'transform') {
					backfill_image($ua, $bucket,
						sprintf("cards/%s/%s-%s.jpg", uc($code), uc($code), $card->{id}),
						$card->{card_faces}[0]{image_uris}{large},
						"[$code] $card->{name} ($card->{id}) front face",
						!!params->{force});

					backfill_image($ua, $bucket,
						sprintf("cards/%s/%s-%s.flip.jpg", uc($code), uc($code), $card->{id}),
						$card->{card_faces}[1]{image_uris}{large},
						"[$code] $card->{name} ($card->{id}) back face",
						!!params->{force});

				} elsif ($card->{image_uris}{large}) {
					backfill_image($ua, $bucket,
						sprintf("cards/%s/%s-%s.jpg", uc($code), uc($code), $card->{id}),
						$card->{image_uris}{large},
						"[$code] $card->{name} ($card->{id})",
						!!params->{force});

				} else {
					warn "unable to find card image url for [$code] $card->{name} (layout:$card->{layout}) in card metadata!\n";
				}
			}

			warn "finished ingesting [$code]\n";
			exit(0);
		}
	}

	return { "ok" => "Set refreshed from upstream data." };
};

#########################################################################
### cache data admin-y things

get '/cards.json' => sub {
	send_file datpath("cards.json"), system_path => 1;
};

get '/sets.json' => sub {
	# for now, this is a live database query
	return [
		map {
			{
				code    => $_->code,
				name    => $_->name,
				release => $_->release,
				size    => $_->get_column('num_cards'),
			}
		} M('Set')->search(
			{},
			{
				join      => 'prints',
				distinct  => 1,
				'+select' => [{ count => 'prints.id', -as => 'num_cards' }],
			},
		)
	];
};

# recache global /cards.json file
post '/v/admin/recache' => sub {
	admin_authn or return admin_authn_failed;

	my %ALL;
	my $Print = M('Print')->search_rs;

	my $pid = fork;
	if ($pid < 0) {
		warn "recache requested for all card data; but background process fork failed!\n";
		return { "error" => "recache requested for all card data; but background process fork failed!" };
	}

	if ($pid == 0) { # in child
		mkdir "dat";
		my $n = 0;
		my $total = $Print->count;
		while (my $card = $Print->next) {
			print "$n/$total cards recached.\n" if $n % 100 == 0;
			$n++;
			push @{$ALL{$card->set_id}}, {
				id       => $card->id,
				set      => { code  => $card->set_id,
				              name  => $card->set->name,
				              total => $card->set->prints->count },
				name     => $card->name,
				type     => $card->type,
				cmc      => $card->cmc,
				cost     => $card->mana,
				color    => $card->color,
				oracle   => $card->oracle,
				artist   => $card->artist,
				flavor   => $card->flavor,
				layout   => $card->layout,
				image    => sprintf("%s/%s-%s.jpg", $card->set_id, $card->set_id, $card->id),
				back     => ($card->layout eq 'transform') ? sprintf("%s/%s-%s.flip.jpg", $card->set_id, $card->set_id, $card->id)
				                                           : undef,
				number   => $card->colnum,
				owned    => 0,
				rarity   => rarity($card->rarity),
				reprint  => !!$card->reprint,
				reserved => !!$card->reserved,
				price    => $card->price,

				power     => $card->power,
				toughness => $card->toughness,
				pt        => $card->power ? ($card->power . '/' . $card->toughness) : undef,

				legal     => from_json($card->legalese),
			};
		}
		print "$n/$total cards recached.\n";

		open my $fh, ">", datpath(".new.json") or do {
			warn "unable to open $DATFILE: $!\n";
			return undef;
		};
		print $fh encode_json(\%ALL);
		close $fh;

		rename datpath(".new.json"),
		       datpath("cards.json");

		exit 0;
	}

	return { ok => "Global cache in progress." };
};

# retrieve cache status for all users + collections
get '/v/admin/cache' => sub {
	admin_authn or return admin_authn_failed;

	# input: (none)

	# output:
	# {
	#   "cache" : {
	#     "fba6aa41-56a5-4ccd-88f2-10ca5856089f": {
	#       "account" : "some-user",
	#       "collections" : {
	#         "81edfc50-0e4b-40fa-95f1-46613b21b785": {
	#           "last-updated" : "2018-12-10 18:39:05",
	#           "size"         : 133161
	#         }
	#       }
	#     }
	#   }
	# }

	my %D = ( cache => {} );

	$D{cache}{$_->id}{account} = $_->account for M('User')->all;
	for my $user (M('User')->all) {
		$D{cache}{$user->id} = {
			account    => $user->account,
			collection => {},
		};

		for my $coll ($user->collections) {
			$D{cache}{$user->id}{collections}{$coll->id} = {};
		}
	}

	find(sub {
		return unless -f;
		my $file = $File::Find::name;
		return unless $file =~ m{/(.*?)/(.*?)/collection.dat$};
		my ($user, $collection) = ($1, $2);

		my (undef, undef, undef, undef, undef, undef, undef,
		    $size, undef, $last) = stat $file;
		$D{cache}{$user}{collections}{$collection} = {
			'last-updated' => $last,
			size           => $size,
		}
	}, datpath());

	return \%D;
};

get '/v/admin/config' => sub {
	admin_authn or return admin_authn_failed;
	return config->{vcb};
};

any '*' => sub {
	status 404;
	return { "error" => "No such endpoint: ".request->uri };
};

1;
