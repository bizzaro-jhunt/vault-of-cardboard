package VCB::DB::Setup;
use strict;
use warnings;

use DBI;

sub migrate {
	my ($class, $dsn) = @_;
	my $version = 0;

	# check for pre-schema_info table
	#  - run init sql
	# check for schema_info (no table = v0)
	#  - run all schema versions strictly greater than schema v
	#  - update schema v after each migration

	############################
	##
	## connect
	##
	print __PACKAGE__.": connecting to $dsn...\n";
	my $db = DBI->connect($dsn, undef, undef, { PrintError => 0 })
		or die __PACKAGE__.": failed to connect to $dsn to run schema migrations: ".DBI->errstr."\n";

	############################
	##
	## check for schema_info table
	##
	if (!$db->prepare('SELECT version FROM schema_info LIMIT 1')) {
		print __PACKAGE__.": schema_info table not found (".$db->errstr.")\n";

		if (!$db->prepare('SELECT id FROM users LIMIT 1')) {
			print __PACKAGE__.": users table not found (".$db->errstr."); initializing schema...\n";
			$class->init($db);
		}

		$db->begin_work;
		$db->do(<<EOF);
CREATE TABLE schema_info (
	version INTEGER NOT NULL DEFAULT 0
)
EOF
		$db->do('INSERT INTO schema_info (version) VALUES (0)');
		$db->commit;
	}

	############################
	##
	## GETV and SETV allow us to interact
	## with the schema_info table.
	##
	my $get_v = $db->prepare('SELECT version FROM schema_info LIMIT 1')
	              or die __PACKAGE__.": failed to prepare GETV SQL query: ".$db->errstr."\n";
	my $set_v = $db->prepare('UPDATE schema_info SET version = ?')
	              or die __PACKAGE__.": failed to prepare SETV SQL query: ".$db->errstr."\n";

	############################
	##
	## what version are we at?
	##
	$version = $get_v->execute() or
		die __PACKAGE__.": failed to determine schema_info version: ".$db->errstr."\n";

	if ($version == 0) {
		print __PACKAGE__.": migrating v0 -> v1 (adding power/toughness to card data)\n";
		$db->do("ALTER TABLE prints ADD COLUMN power     TEXT NOT NULL DEFAULT ''");
		$db->do("ALTER TABLE prints ADD COLUMN toughness TEXT NOT NULL DEFAULT ''");
		$set_v->execute(++$version);
	}
}

sub init {
	my ($class, $db) = @_;

	$db->begin_work;
	$db->do(<<EOF);
CREATE TABLE sets (
  code    VARCHAR(6) NOT NULL PRIMARY KEY,
  name    TEXT       NOT NULL UNIQUE,
  release DATE       NOT NULL
)
EOF

	$db->do(<<EOF);
CREATE TABLE prints (
  id        UUID        NOT NULL PRIMARY KEY,
  name      TEXT,
  type      TEXT,
  oracle    TEXT,
  flavor    TEXT,

  set_id    VARCHAR(6)  NOT NULL,
  colnum    TEXT        DEFAULT NULL,
  rarity    VARCHAR(1), -- M/R/U/C
  reprint   BOOLEAN     NOT NULL DEFAULT 0,
  reserved  BOOLEAN     NOT NULL DEFAULT 0,
  color     VARCHAR(6), -- any of WUBRGC
  mana      VARCHAR(20) NOT NULL DEFAULT '',
  cmc       INTEGER     NOT NULL DEFAULT 0,
  artist    TEXT,
  price     DECIMAL     NOT NULL DEFAULT 0,

  FOREIGN KEY (set_id) REFERENCES sets (code)
)
EOF

	$db->do(<<EOF);
CREATE TABLE users (
  id        UUID         NOT NULL PRIMARY KEY,
  account   VARCHAR(100) NOT NULL UNIQUE,
  pwhash    TEXT,
  display   TEXT,
  joined_at INTEGER      NOT NULL,
  admin     BOOLEAN      NOT NULL DEFAULT 0,
  active    BOOLEAN      NOT NULL DEFAULT 1
)
EOF

	$db->do(<<EOF);
CREATE TABLE collections (
  id      UUID        NOT NULL PRIMARY KEY,
  user_id UUID        NOT NULL,
  main    BOOLEAN     NOT NULL DEFAULT 0,
  type    VARCHAR(10) NOT NULL DEFAULT 'collection',
  name    TEXT,
  notes   TEXT,

  UNIQUE (user_id, name),
  FOREIGN KEY (user_id) REFERENCES users(id)
)
EOF

	$db->do(<<EOF);
CREATE TABLE cards (
  id               UUID NOT NULL PRIMARY KEY,

  print_id UUID DEFAULT NULL,

  proxied          BOOLEAN    NOT NULL DEFAULT 0,
  flags            VARCHAR(1) NOT NULL DEFAULT '',  -- ONE OF F
  quantity         INTEGER    NOT NULL DEFAULT 0,
  quality          VARCHAR(2) NOT NULL DEFAULT 'G', -- ONE OF M/NM/EX/VG/G/P
  collection_id    UUID       NOT NULL,

  FOREIGN KEY (print_id)      REFERENCES prints      (id),
  FOREIGN KEY (collection_id) REFERENCES collections (id)
)
EOF

	$db->do(<<EOF);
CREATE TABLE sessions (
  id   INTEGER NOT NULL PRIMARY KEY,
  data TEXT NOT NULL
)
EOF
	$db->commit;
}

1;