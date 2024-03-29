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

if (!$ENV{TEST_ACTIVE}) {
	print STDERR "ENV> $_ = '$ENV{$_}'\n" for sort keys %ENV;
}

if (POSIX::getpid() == 1) {
	print STDERR "installing signal handlers...\n";
	$SIG{TERM} = $SIG{INT} = sub { exit 0 };
}

my %SESH;

#########################################################################

sub logf {
	print STDERR "$@";
}

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
	my $cookie = cookie 'vcb_sesh';
	if ($cookie && $cookie->value) {
		return $SESH{$cookie->value};
	}

	# fall back to basic auth
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

	my ($username, $password) = split ':', decode_base64($1), 2;
	return M('User')->authenticate($username, $password);
}

sub admin_authn {
	my $user = authn
		or return undef;

	if (!$user->admin) {
		status 403;
		response_header 'WWW-Authenticate' => 'Basic realm="Vault of Cardboard"';
		return undef;
	}

	return $user;
}

sub admin_authn_failed {
	return { error => "Administrative authentication required." };
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
	logf "checking image state for $msg...\n";
	if ($force || !$bucket->head_key($ours)) {
		logf "backfilling image for $msg...\n";
		my $res = $ua->get($theirs);
		if (!$res->is_success) {
			logf "failed to retrieve card face $msg '$theirs': ".$res->status_line."\n";
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
		cohort    => 'preview',
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

get '/my/timeline' => sub {
	my $user = authn or return {
		"error" => "You are not logged in.",
		"authn" => "required"
	};
	redirect sprintf("/v/%s/timeline", $user->id);
};

post '/v/import/validate' => \&do_v_import_validate;
sub do_v_import_validate {
	# input:
	# {
	#    "vif" : "... (a formatted import string) ..."
	# }

	# output:
	# {
	#   "vif" : "... (possible re-formatted import string) ...",
	#   "ok"  : "Looks good!"
	# }
	#
	# or:
	#
	# {
	#   "vif"   : "... (possible re-formatted import string) ...",
	#   "error" : "Validation failed",
	#   "problems" : [
	#     {
	#       "wanted" : {
	#         "line"     : "2x MIR Askari",
	#         "lineno"   : 14,
	#         "quantity" : 2
	#       },
	#       "description" : "More than one match found",
	#       "candidates"  : [
	#         "486547cd-d2e7-4c46-9f7b-81c4267d65cc",
	#         "5cf66916-7f6b-412f-acd6-f96ad4539a46"
	#       ]
	#     }
	#   ]
	# }

	local $@;
	my $cards = eval { VCB::Format->parse(request->data->{vif}); };
	if ($@) {
		logf "unable to parse input: $@\n";
		return { error   => "Syntax error in import: $@" };
	}

	# convert everything to Standard format, for ease of clarification
	# on the front end (having to handle too many import formats complicates
	# the diffing algorithm beyond reason)
	#
	my $vif = VCB::Format::Standard->format($cards);

	my @problems;
	for my $card (@$cards) {
		my ($print, $candidates);

		print STDERR "checking on $card->{name} [$card->{set}]...\n";

		# check for exact match; if found, we're 100% ok
		$print = M('Print')->search(
			{ name   => $card->{name},
			  set_id => $card->{set}})->count
				and next;

		my $wanted = {
			card     => $card->{name},
			set      => $card->{set},
			line     => $card->{_parser}{text},
			lineno   => $card->{_parser}{line},
			quantity => $card->{quantity},
		};

		# check if we are a basic land
		if ($card->{name} =~ m/^(plains|island|swamp|mountain|forest)$/i) {
			$candidates = M('Print')->search_rs(
				{ name     => $card->{name},
				  set_id   => 'M19' },
				{ group_by => [qw[ name set_id] ],
				  rows     => 16 });
			if ($candidates && $candidates->count > 0) {
				push @problems, {
					wanted      => $wanted,
					description => "not found in set <em>$card->{set}</em>",
					candidates  => [map { $_->id } $candidates->all],
				};
				next;
			}
		}

		# check to see if the card exists by name in other sets
		$candidates = M('Print')->search_rs(
			{ name     => $card->{name} },
			{ group_by => [ qw[name set_id] ],
			  rows     => 16 });
		if ($candidates && $candidates->count > 0) {
			push @problems, {
				wanted      => $wanted,
				description => "not found in set <em>$card->{set}</em>, but was found in other sets",
				candidates  => [map { $_->id } $candidates->all],
			};
			next;
		}

		# check a few looser, name-based searches, within the set and otherwise
		# FIXME: implement Askari -> A.*i searches
		$candidates = M('Print')->search_rs(
			{ name     => { like => "%$card->{name}%" },
			  set_id   => $card->{set} },
			{ order_by => { -asc => 'name' },
			  rows     => 16 });
		if ($candidates && $candidates->count > 0) {
			push @problems, {
				wanted      => $wanted,
				description => "not found, but a fuzzy search found these other cards",
				candidates  => [map { $_->id } $candidates->all],
			};
			next;
		}
		$candidates = M('Print')->search_rs(
			{ name     => { like => "%$card->{name}%" } },
			{ order_by => { -asc => 'name' },
			  rows     => 16 });
		if ($candidates && $candidates->count > 0) {
			push @problems, {
				wanted      => $wanted,
				description => "not found, but a fuzzy search found these other cards",
				candidates  => [map { $_->id } $candidates->all],
			};
			next;
		}

		# finally, give up.
		push @problems, {
			wanted      => $wanted,
			description => "not found in the Vault's database",
			candidates  => [],
		};
	}

	if (@problems) {
		return {
			vif      => $vif,
			error    => "validation failed",
			problems => \@problems,
		};
	}

	return {
		vif => $vif,
		ok  => "validated!",
	};
};

sub analyze_import {
	my $what = {
		raw    => $_[0] || '',
		card   => 0,
		unique => 0,
		sets   => {},
	};

	my $cards = VCB::Format->parse($what->{raw});
	for my $card (@$cards) {
		$what->{card} += $card->{quantity};
		$what->{unique}++;
		$what->{sets}{$card->{set}} = 1;
	}

	return $what;
}

post '/my/changes' => \&do_my_changes;
sub do_my_changes {
	my $user = authn or return {
		"error" => "You are not logged in.",
		"authn" => "required"
	};

	my $gain = analyze_import(request->{data}{raw_gain});
	my $loss = analyze_import(request->{data}{raw_loss});
	my %sets = (%{$gain->{sets}}, %{$loss->{sets}});

	my $occurred = (request->{data}{type} eq "import")
	             ? 0 : request->{data}{occurred_at};
	$user->changes->create({
		id          => uuidgen(),
		occurred_at => $occurred,
		type        => request->{data}{type},
		summary     => request->{data}{summary},
		notes       => request->{data}{notes}    || '',

		raw_gain    => $gain->{raw},
		card_gain   => $gain->{card},
		unique_gain => $gain->{unique},

		raw_loss    => $loss->{raw},
		card_loss   => $loss->{card},
		unique_loss => $loss->{unique},

		sets        => join(':', sort keys %sets),
		analyzed    => 1,
	}) or die "failed to create change: $!\n";

	recache($user, $user->primary_collection);
	return {
		ok => "Collection change recorded",
	};
};

get '/my/decks' => \&do_GET_my_decks;
sub do_GET_my_decks {
	my $user = authn or return {
		"error" => "You are not logged in.",
		"authn" => "required"
	};

	return [map {
		{
			code     => $_->code,
			name     => $_->name,
			notes    => $_->notes,
			cover    => $_->cover,
			format   => $_->format,
			cardlist => $_->cardlist,

			created_at => $_->created_at,
			updated_at => $_->updated_at,
		}
	} $user->decks];
}

post '/my/decks' => \&do_POST_my_decks;
sub do_POST_my_decks {
	my $user = authn or return {
		"error" => "You are not logged in.",
		"authn" => "required"
	};

	# input:
	# {
	#   "code"     : "a-code-name",
	#   "name"     : "A Public Deck Name",
	#   "notes"    : "Some notes about this deck\n\nPossible multi-line...",
	#   "cover"    : "... a card UUID ...",
	#   "format"   : "standard",
	#   "cardlist" : "... a VCB-formatted string ..."
	# }

	# output:
	# {
	#   "ok" : "Deck created"
	# }

	my $format = lc(request->data->{format} || 'custom');
	if ($format !~ m/^(standard|modern|vintage|legacy|edh|pauper|custom)$/) {
		status 400;
		return { error => sprintf("Unrecognized deck format '%s'", $format) };
	}

	my $code = lc(request->data->{code});
	if ($code !~ m/^[a-z][a-z0-9_-]+/) {
		status 400;
		return { error => sprintf("Improperly formatted deck code '%s'", $code) };
	}

	my $deck = $user->decks->create({
		id       => uuidgen(),
		code     => $code,
		name     => request->data->{name},
		notes    => request->data->{notes} || '',
		cover    => request->data->{cover} || '',
		format   => $format,
		cardlist => request->data->{cardlist},

		created_at => time(),
		updated_at => time(),
	});

	recache($user, $user->primary_collection);
	return { ok => "Deck created" };
}

get '/my/decks/:code' => \&do_GET_my_decks_x;
sub do_GET_my_decks_x {
	my $user = authn or return {
		"error" => "You are not logged in.",
		"authn" => "required"
	};

	my $code = params->{code};
	my @decks = $user->decks->search({ code => $code });
	if (!@decks) {
		status 404;
		return { error => sprintf("Deck '%s' not found", $code) };
	}
	if (@decks > 1) {
		status 500;
		return { error => sprintf("More than one deck with code '%s' found", $code) };
	}

	my ($deck) = @decks;
	return {
		id       => $deck->id,
		code     => $deck->code,
		name     => $deck->name,
		notes    => $deck->notes,
		cover    => $deck->cover,
		format   => $deck->format,
		cardlist => $deck->cardlist,

		created_at => $deck->created_at,
		updated_at => $deck->updated_at,
	};
}

put '/my/decks/:code' => \&do_PUT_my_decks_x;
sub do_PUT_my_decks_x {
	my $user = authn or return {
		"error" => "You are not logged in.",
		"authn" => "required"
	};

	# input:
	# {
	#   "name"     : "A Public Deck Name",
	#   "notes"    : "Some notes about this deck\n\nPossible multi-line...",
	#   "cover"    : "... a card UUID ...",
	#   "format"   : "standard",
	#   "cardlist" : "... a VCB-formatted string ..."
	# }

	# output:
	# {
	#   "ok" : "Deck updated"
	# }

	my $code = params->{code};
	my @decks = $user->decks->search({ code => $code });
	if (!@decks) {
		status 404;
		return { error => sprintf("Deck '%s' not found", $code) };
	}
	if (@decks > 1) {
		status 500;
		return { error => sprintf("More than one deck with code '%s' found", $code) };
	}

	my ($deck) = @decks;
	$deck->update({
		code     => request->data->{code}     || $deck->code,
		name     => request->data->{name}     || $deck->name,
		notes    => request->data->{notes},
		cover    => request->data->{cover}    || $deck->cover,
		format   => request->data->{format}   || $deck->format,
		cardlist => request->data->{cardlist},

		updated_at => time(),
	});

	recache($user, $user->primary_collection);
	return { ok => "Deck updated" };
}

del '/my/decks/:code' => \&do_DEL_my_decks_x;
sub do_DEL_my_decks_x {
	my $user = authn or return {
		"error" => "You are not logged in.",
		"authn" => "required"
	};

	# input: (none)

	# output:
	# {
	#   "ok" : "Deck deleted"
	# }

	my $code = params->{code};
	my @decks = $user->decks->search({ code => $code });
	if (!@decks) {
		status 404;
		return { error => sprintf("Deck '%s' not found", $code) };
	}
	if (@decks > 1) {
		status 500;
		return { error => sprintf("More than one deck with code '%s' found", $code) };
	}

	my ($deck) = @decks;
	$deck->delete;

	recache($user, $user->primary_collection);
	return { ok => "Deck deleted" };
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

sub recache {
	my ($user, $col) = @_;
	my (%HAVE, %ALL);

	$col->replay($user->changes);

	mkdir datpath();
	mkdir datpath($user->id);
	mkdir datpath($user->id, 'col');

	printf STDERR "caching collection '%s' [%s] for user '%s' [%s] in VCB format...\n",
		$col->name || "(unnamed)", $col->id, $user->account, $user->id;
	open my $fh, ">", datpath($user->id, "col/.new.vcb") or do {
		logf "unable to open $DATFILE: $!\n";
		return undef;
	};
	for my $card ($col->cards) {
		$HAVE{$card->print->set_id}{$card->print->name} += $card->quantity;
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

	for my $deck ($user->decks) {
		my $cards = eval { VCB::Format->parse($deck->cardlist); };
		for my $card (@$cards) {
			$HAVE{_decked}{$card->{name}}{$deck->code} = 1;
		}
	}

	open $fh, ">", datpath($user->id, "col/.new.json") or do {
		logf "unable to open $DATFILE: $!\n";
		return undef;
	};
	print $fh encode_json(\%HAVE);
	close $fh;

	rename datpath($user->id, "col/.new.json"),
	       datpath($user->id, "col", $user->primary_collection->id.".json");

	return 1;
}

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

get '/v/:user/timeline' => \&do_v_user_timeline;
sub do_v_user_timeline {
	my $user = M('User')->find(param('user'))
		or return {};

	return [map {
		{
			id          => $_->id,
			type        => $_->type,
			occurred_at => $_->occurred_at,
			summary     => $_->summary,
			notes       => $_->notes,
			analyzed    => $_->analyzed,
			card_gain   => $_->card_gain,
			unique_gain => $_->unique_gain,
			card_loss   => $_->card_loss,
			unique_loss => $_->unique_loss,
			sets        => $_->sets,
		}
	} $user->changes ];
};

#get '/v/col/:user' => sub {
#	my $user = M('User')->find(param('user'))
#		or return {}; # FIXME
#
#	return [map {
#		{
#			id    => $_->id,
#			name  => $_->name,
#			notes => $_->notes,
#			type  => $_->type,
#		}
#	} $user->collections];
#};

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
	} elsif ($ext eq 'vcb' or $ext eq 'vif') {
		send_as plain => "# you don't have any cards yet...\n";
	} elsif ($ext eq 'json') {
		return {};
	}
};

#########################################################################
### authz

get '/v/whoami' => \&do_v_whoami;
sub do_v_whoami {
	my $user = authn;
	if ($user) {
		return {
			id      => $user->id,
			account => $user->account,
			display => $user->display,
			cohort  => $user->cohort,
		};
	}
	return {};
}

post '/v/login' => \&do_v_login;
sub do_v_login {
	my $user = M('User')->authenticate(param('username'), param('password'));

	if ($user) {
		my $sid = randstr(64);
		$SESH{$sid} = $user;
		cookie vcb_sesh  => $sid,
		       expires   => '90d',
		       same_site => 'Strict',
		       http_only => 1;
		return {
			ok => "Authenticated successfully.",
			user => {
				id      => $user->id,
				account => $user->account,
				display => $user->display,
				cohort  => $user->cohort,
				session => $sid,
			},
		};
	}

	status 401;
	return { error => "Invalid username or password." };
}

post '/v/logout' => \&do_v_logout;
sub do_v_logout {
	delete $SESH{cookie 'vcb_sesh'};
	return { ok => "Logged out." };
}

#########################################################################
### user admin-y things

# create a new user
post '/v/admin/users' => sub {
	admin_authn or return admin_authn_failed;

	# input:
	# {
	#   "account" : "username",
	#   "display" : "User Name",
	#   "cohort"  : "public"
	# }

	# output:
	# {
	#   "ok"      : "Created user account",
	#   "created" : {
	#     "id"        : "ab9c5636-b05e-479f-a7c9-21b45f34ef66",
	#     "account"   : "username",
	#     "cohort"    : "public",
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
			cohort    => param('cohort') || 'public',
			display   => param('display'),
			joined_at => time(),
			active    => 1,
		})->set_password($pw)
		  ->insert;
	};
	if ($@) {
		logf "failed to create user account '".param('account')."': ".$@."\n";
		return { error => "Unable to create account; check server logs for details." };
	}

	$u->collections->create({
		id   => uuidgen(),
		main => 1,
		type => 'collection',
	}) or do {
		logf "failed to create primary collection for user account".$u->account."\n";
		return { error => "Unable to create primary collection; check server logs for details." };
	};

	return {
		ok => "Created user account",
		created => {
			id        => $u->id,
			account   => $u->account,
			cohort    => $u->cohort,
			display   => $u->display,
			joined_at => strftime("%Y-%m-%d %H:%M:%S %z", gmtime($u->joined_at)),
			active    => $u->active,
			password  => $pw,
		},
	}
};

# upate a user
put '/v/admin/users/:account' => sub {
	admin_authn or return admin_authn_failed;

	# input:
	# {
	#   "account" : "username",
	#   "display" : "User Name",
	#   "cohort"  : "public"
	# }

	# output:
	# {
	#   "ok"      : "Updated user account",
	#   "updated" : {
	#     "id"        : "ab9c5636-b05e-479f-a7c9-21b45f34ef66",
	#     "account"   : "username",
	#     "cohort"    : "public",
	#     "display"   : "User Name",
	#     "joined_at" : "2018-12-10 14:19:04",
	#     "active"    : true
	#   }
	# }

	my $u = M('User')->find({ account => param('account') });
	if (!$u) {
		status 404;
		return { error => "User '".param('account')."' not found" };
	}

	local $@;
	eval {
		$u->update({
			account   => request->data->{account} || $u->account,
			cohort    => request->data->{cohort}  || $u->cohort || 'public',
			display   => request->data->{display} || $u->display,
		});
	};
	if ($@) {
		logf "failed to update user account '".param('account')."': ".$@."\n";
		return { error => "Unable to update account; check server logs for details." };
	}

	return {
		ok => "Updated user account",
		updated => {
			id        => $u->id,
			account   => $u->account,
			cohort    => $u->cohort,
			display   => $u->display,
			joined_at => strftime("%Y-%m-%d %H:%M:%S %z", gmtime($u->joined_at)),
			active    => $u->active,
		},
	};
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
		cohort    => $_->cohort,
		joined_at => strftime("%Y-%m-%d %H:%M:%S %z", localtime($_->joined_at)),
		active    => $_->active,
	}} M('User')->search];
};

#########################################################################
### collection admin-y things

# update a change
post '/v/admin/users/:uuid/changes' => sub {
	admin_authn or return admin_authn_failed;

	# input: (a VCB-formatted string)

	# output:
	# {
	#   "ok" : "Collection updated."
	# }

	my $user = M('User')->find(param('uuid'));
	if (!$user) {
		logf "unable to find user '".param('uuid')."'\n";
		return { error => "No such user." };
	}

	my $gain = analyze_import(request->{data}{raw_gain});
	my $loss = analyze_import(request->{data}{raw_loss});
	my %sets = (%{$gain->{sets}}, %{$loss->{sets}});

	my $occurred = (request->{data}{type} eq "import")
	             ? 0 : request->{data}{occurred_at};
	$user->changes->create({
		id          => uuidgen(),
		occurred_at => $occurred,
		type        => request->{data}{type},
		summary     => request->{data}{summary},
		notes       => request->{data}{notes}    || '',

		raw_gain    => $gain->{raw},
		card_gain   => $gain->{card},
		unique_gain => $gain->{unique},

		raw_loss    => $loss->{raw},
		card_loss   => $loss->{card},
		unique_loss => $loss->{unique},

		sets        => join(':', sort keys %sets),
		analyzed    => 1,
	}) or die "failed to create change: $!\n";


	return { ok => "Collection change recorded." };
};

#########################################################################
### card set admin-y things

# ingest a set of cards, from upstream data
post '/v/admin/sets/:code/ingest' => \&do_v_admin_sets_x_ingest;
sub do_v_admin_sets_x_ingest {
	admin_authn or return admin_authn_failed;

	# input: (none)

	# output:
	# {
	#    "ok": "Set refreshed from upstream data."
	# }

	my @cards;
	my $crit = 1;
	my $s;

	for my $code (lc(param('code')), 't'.(lc(param('code')))) {
		logf "ingesting set [$code]...\n";
		my $cache = cachepath("$code.set");
		if (-f $cache) {
			logf "checking if our cache file needs to be re-synced or not...\n";
			my $mtime = (stat($cache))[9];
			if (time - $mtime > config->{vcb}{cachefor} * 86400) {
				logf "cache file is ".((time - $mtime)/86400.0)." day(s) old (> ".config->{vcb}{cachefor}."); invalidating.\n";
				unlink $cache;
			}
		}
		if (! -f $cache) {
			if ($ENV{VCB_NO_SCRYFALL}) {
				next unless $crit;
				return { error => "Querying of Scryfall API prohibited by local configuration" };
			}

			print "cache path '$cache' not found; pulling [$code] from scryfall...\n";

			my $scry = Scry->new;
			my $set = $scry->get1("/sets/$code") or do {
				next unless $crit;
				logf "failed to query ScryFall API for set [$code] data\n";
				return { "error" => "Failed to query Scryfall API." };
			};

			print "querying $set->{search_uri} ...\n";
			$set->{cards} = $scry->get($set->{search_uri}) or do {
				logf "failed to query ScryFall API for set [$code] card data\n";
				return { "error" => "Failed to query Scryfall API." };
			};

			open my $fh, ">", $cache or do {
				logf "failed to open cache file '$cache': $!\n";
				return { error => "failed to open cache file '$cache': $!" };
			};
			print $fh encode_json($set);
			close $fh;
		}

		open my $fh, "<", $cache
			or return { error => "failed to read cache file: $!" };

		my $set = decode_json(do { local $/; <$fh> });
		close $fh;

		$set->{set} = uc($set->{set} || $code);
		$set->{set} =~ s/^T// if $set->{set} =~ m/^T...$/;
		$s = M('Set')->find({ code => $set->{set} })
		  || M('Set')->create({
		                 code    => $set->{set},
		                 name    => $set->{name},
		                 release => 0, # temporary
		});

		@cards = (@cards, @{$set->{cards}});
		$crit = 0;
	}

	my $code = $s->code;
	my %dates; # majority-wins release dating
	my %existing = map { $_->id => $_ } $s->prints;
	for my $card (@cards) {
		$dates{$card->{released_at}}++;

		logf "updating $code $card->{name}...\n";
		my $attrs = {
			id        => $card->{id},
			oid       => $card->{oracle_id}       || 'self:'.$card->{id},
			art       => $card->{illustration_id} || 'self:'.$card->{id},
			name      => $card->{name},
			oracle    => ($card->{card_faces} ? join("\n---\n", map { $_->{oracle_text} } @{$card->{card_faces}}) : $card->{oracle_text}) || '',
			type      => $card->{type_line},
			colnum    => $card->{collector_number},
			flavor    => ($card->{card_faces} ? join("\n---\n", map { $_->{flavor_text} } @{$card->{card_faces}}) : $card->{flavor_text}) || '',
			rarity    => substr($card->{rarity}, 0, 1),
			reprint   => !!$card->{reprint},
			reserved  => !!$card->{reserved},
			spotlight => !!$card->{story_spotlight},
			color     => join('', sort(@{$card->{color_identity} || []})),
			cmc       => $card->{cmc},
			mana      => ($card->{card_faces} ? $card->{card_faces}[0]{mana_cost} : $card->{mana_cost}) || '',
			artist    => $card->{artist},
			price     => $card->{usd} || 0,
			power     => $card->{power}     || '',
			toughness => $card->{toughness} || '',
			layout    => $card->{layout},
			legalese  => to_json($card->{legalities} || {}),
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
		next if $dates{$dated} < 0.6 * scalar(@cards);
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
			logf "card images refresh requested for set [$code]; but no S3 configuration found!\n";
			return { "error" => "Set refreshed from upstream data; but no S3 configuration was found for image refresh." };
		}

		my $pid = fork;
		if ($pid < 0) {
			logf "card image refresh requested for set [$code]; but background process fork failed!\n";
			return { "error" => "Set refreshed from upstream data; but the background process for image refresh failed to fork." };
		}

		if ($pid == 0) { # in child
			logf "connecting to s3 as $aki\n";
			my $s3 = Net::Amazon::S3->new({
				aws_access_key_id     => $aki,
				aws_secret_access_key => $key,
			});

			my $bucket = $s3->bucket(config->{vcb}{s3}{bucket});
			if (!$bucket || !$bucket->get_acl) {
				logf "card images refresh requested for set [$code]; but bucket '".config->{vcb}{s3}{bucket}."' not found!\n";
				exit(1);
			};

			my $ua = LWP::UserAgent->new(
				agent => 'mtgc-alpha/0.1',
				ssl_opts => { verify_hostname => 0 },
			);

			for my $card (@cards) {
				if ($card->{layout} eq 'transform' or $card->{layout} eq 'double_faced_token') {
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
					logf "unable to find card image url for [$code] $card->{name} (layout:$card->{layout}) in card metadata!\n";
				}
			}

			logf "finished ingesting [$code]\n";
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

get '/sets.json' => \&do_sets_dot_json;
sub do_sets_dot_json {
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
}

# recache global /cards.json file
post '/v/admin/recache' => sub {
	admin_authn or return admin_authn_failed;

	my %ALL;
	my $Print = M('Print')->search_rs;

	my $pid = fork;
	if ($pid < 0) {
		logf "recache requested for all card data; but background process fork failed!\n";
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
				id        => $card->id,
				oid       => $card->oid,
				art       => $card->art,
				set       => { code  => $card->set_id,
				               name  => $card->set->name,
				               total => $card->set->prints->count },
				name      => $card->name,
				type      => $card->type,
				cmc       => $card->cmc,
				cost      => $card->mana,
				color     => $card->color,
				oracle    => $card->oracle,
				artist    => $card->artist,
				flavor    => $card->flavor,
				layout    => $card->layout,
				image     => sprintf("%s/%s-%s.jpg", $card->set_id, $card->set_id, $card->id),
				back      => ($card->layout eq 'transform' ||
				              $card->layout eq 'double_faced_token')
				                ? sprintf("%s/%s-%s.flip.jpg", $card->set_id, $card->set_id, $card->id)
				                : undef,
				number    => $card->colnum,
				owned     => 0,
				rarity    => rarity($card->rarity),
				reprint   => !!$card->reprint,
				reserved  => !!$card->reserved,
				spotlight => !!$card->spotlight,
				price     => $card->price,

				power     => $card->power,
				toughness => $card->toughness,
				pt        => $card->power ? ($card->power . '/' . $card->toughness) : undef,

				legal     => from_json($card->legalese || '{}'),
			};
		}
		print "$n/$total cards recached.\n";

		open my $fh, ">", datpath(".new.json") or do {
			logf "unable to open $DATFILE: $!\n";
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
