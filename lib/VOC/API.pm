package VOC::API;
use strict;
use warnings;

use POSIX qw/strftime/;
use Data::Dumper;
use Data::UUID;
use File::Find;
use Cwd qw/cwd/;
use MIME::Base64 qw/decode_base64/;

use VOC::Format::Standard;
use Scry;

use Dancer2;
use Dancer2::Plugin::DBIC;

set serializer => 'JSON';

my %SESH;

#########################################################################

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

#########################################################################

if (M('User')->count == 0 && $ENV{VOC_FAILSAFE_USERNAME} && $ENV{VOC_FAILSAFE_PASSWORD}) {
	my $admin = M('User')->create({
		id        => uuidgen(),
		account   => $ENV{VOC_FAILSAFE_USERNAME},
		pwhash    => $ENV{VOC_FAILSAFE_PASSWORD},
		display   => $ENV{VOC_FAILSAFE_USERNAME},
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

get '' => sub {
	redirect => '/index.html';
};

get '/my/:type' => sub {
	my $user = authn or return {
		"error" => "You are not logged in.",
		"authn" => "required"
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
	#   "voc" : "... (a VOC-formatted string) ..."
	# }

	# output:
	# {
	#   "ok" : "Collection validated."
	# }

	local $@;
	my @errors = eval { validate_cards(VOC::Format::Standard->parse(request->data->{voc})); };
	if ($@) {
		warn "unable to parse input: $@\n";
		return { error => "Invalid VOC request payload." };
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

	mkdir "dat";
	mkdir "dat/".$user->id;
	mkdir "dat/".$user->id."/col";

	printf STDERR "caching collection '%s' [%s] for user '%s' [%s] in VOC format...\n",
		$col->name, $col->id, $user->account, $user->id;
	open my $fh, ">", "dat/".$user->id."/col/.new.voc" or do {
		warn "unable to open"."dat/".$user->id."/col/.new.voc: $!\n";
		return undef;
	};
	for my $card ($col->cards) {
		$HAVE{$card->print->set_id}{$card->print->name} = $card->quantity;
		VOC::Format::Standard->print1($fh, {
			name      => $card->print->name,
			set       => $card->print->set_id,
			condition => $card->quality,
			quantity  => $card->quantity,
			flags     => $card->flags,
		});
	}
	close $fh;
	rename "dat/".$user->id."/col/.new.voc",
	       "dat/".$user->id."/col/".$user->primary_collection->id.".voc";

	open $fh, ">", "dat/".$user->id."/col/.new.json" or do {
		warn "unable to open"."dat/".$user->id."/col/.new.json: $!\n";
		return undef;
	};
	print $fh encode_json(\%HAVE);
	close $fh;

	rename "dat/".$user->id."/col/.new.json",
	       "dat/".$user->id."/col/".$user->primary_collection->id.".json";

	return 1;
}

put '/my/collection' => sub {
	my $user = authn or return {
		"error" => "You are not logged in.",
		"authn" => "required"
	};

	# input: (a VOC-formatted string)

	# output:
	# {
	#   "ok" : "Collection updated."
	# }

	local $@;
	my $cards = eval { VOC::Format::Standard->parse(request->data->{voc}); };
	if ($@) {
		warn "unable to parse input: $@\n";
		return { error => "Invalid VOC request payload." };
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
	my $user = M('User')->find(param('user'))
		or return {};
	redirect sprintf("/v/col/%s/%s/%s",
		$user->id, $user->primary_collection->id, param('type'));
};

get '/v/col/:user/:uuid/:type' => sub {
	# grab a collection, owned by a given user.
	#
	# these are statically-generated, so all we do here is validate
	# the requesting session against the given user UUID (:user)
	# and then translate that to a filesystem send call.

	(my $ext = param('type')) =~ s/^.*?\.//;
	my $file = sprintf("dat/%s/col/%s.%s", param('user'), param('uuid'), $ext);

	if (! -f $file) {
		status 404;
		return { error => "No such collection." };
	}

	send_file cwd."/$file", system_path => 1;
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

	# input: (a VOC-formatted string)

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
	my $cards = eval { VOC::Format::Standard->parse(request->data->{voc}); };
	if ($@) {
		warn "unable to parse input: $@\n";
		return { error => "Invalid VOC request payload." };
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

	# input: (a VOC-formatted string)

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
	my $cache = lc("cache/$code.set");
	if (! -f $cache) {
		mkdir "cache";
		print "pulling [$code] from scryfall...\n";
		open my $fh, ">", $cache
			or return { error => "failed to open cache file: $!" };

			print "talking to scry...\n";
		my $scry = Scry->new;
		my $set = $scry->get1("/sets/$code")
			or return {
				"error" => "Failed to query Scryfall API.",
			};

		$set->{cards} = $scry->get($set->{search_uri})
			or return {
				"error" => "Failed to query Scryfall API.",
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
			release => 12345, # FIXME
		});
	}

	my %existing = map { $_->id => $_ } $s->prints;
	for my $card (@{$set->{cards}}) {
		print "updating $set->{set} $card->{name}...\n";
		my $attrs = {
			id        => $card->{id},
			name      => $card->{name},
			oracle    => $card->{oracle_text},
			type      => $card->{type_line},
			colnum    => $card->{collector_number},
			flavor    => $card->{flavor_text},
			rarity    => substr($card->{rarity}, 0, 1),
			reprint   => !!$card->{reprint},
			reserved  => !!$card->{reserved},
			color     => join('', sort(@{$card->{color_identity}})),
			cmc       => $card->{cmc},
			mana      => ($card->{card_faces} ? $card->{card_faces}[0]{mana_cost} : $card->{mana_cost}) || '',
			artist    => $card->{artist},
			price     => $card->{usd} || 0,
		};
		my $rc = $existing{$card->{id}};
		if ($rc) {
			$rc->update($attrs);
			delete $existing{$card->{id}};
		} else {
			$s->prints->create($attrs);
		}
	}

	my @ids;
	push @ids, $_ for keys %existing;
	$s->prints->search({ id => \@ids })->delete
		if @ids;

	return { "ok" => "Set refreshed from upstream data." };
};

#########################################################################
### cache data admin-y things

get '/cards.json' => sub {
	send_file cwd."/dat/cards.json", system_path => 1;
};

# recache global /cards.json file
post '/v/admin/recache' => sub {
	admin_authn or return admin_authn_failed;

	my %ALL;
	my $Print = M('Print')->search_rs;

	mkdir "dat";
	while (my $card = $Print->next) {
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
			image    => sprintf("%s/%s-%s.jpg", $card->set_id, $card->set_id, $card->id),
			number   => $card->colnum,
			owned    => 0,
			rarity   => rarity($card->rarity),
			reprint  => !!$card->reprint,
			reserved => !!$card->reserved,
			price    => $card->price,
		};
	}

	open my $fh, ">", "dat/.new.json" or do {
		warn "unable to open"."dat/.new.json: $!\n";
		return undef;
	};
	print $fh encode_json(\%ALL);
	close $fh;

	rename "dat/.new.json",
	       "dat/cards.json";

	return { ok => "Global cache updated." };
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
		return unless $file =~ m{^dat/(.*?)/(.*?)/collection.dat$};
		my ($user, $collection) = ($1, $2);

		my (undef, undef, undef, undef, undef, undef, undef,
		    $size, undef, $last) = stat $file;
		$D{cache}{$user}{collections}{$collection} = {
			'last-updated' => $last,
			size           => $size,
		}
	}, "dat");

	return \%D;
};

any '*' => sub {
	status 404;
	return { "error" => "No such endpoint: ".request->uri };
};

1;
