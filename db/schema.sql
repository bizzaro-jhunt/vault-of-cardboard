--
-- Vault of Cardboard Database Schema
-- (assumes SQLite, but should work with PG)
--

CREATE TABLE IF NOT EXISTS sets (
	code    VARCHAR(6) NOT NULL PRIMARY KEY,
	name    TEXT       NOT NULL UNIQUE,
	release DATE       NOT NULL
);

CREATE TABLE IF NOT EXISTS prints (
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
);

CREATE TABLE IF NOT EXISTS users (
	id        UUID         NOT NULL PRIMARY KEY,
	account   VARCHAR(100) NOT NULL UNIQUE,
	pwhash    TEXT,
	display   TEXT,
	joined_at INTEGER      NOT NULL,
	admin     BOOLEAN      NOT NULL DEFAULT 0,
	active    BOOLEAN      NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS collections (
	id      UUID        NOT NULL PRIMARY KEY,
	user_id UUID        NOT NULL,
	main    BOOLEAN     NOT NULL DEFAULT 0,
	type    VARCHAR(10) NOT NULL DEFAULT 'collection',
	name    TEXT,
	notes   TEXT,

	UNIQUE (user_id, name),
	FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS cards (
	id               UUID NOT NULL PRIMARY KEY,

	print_id UUID DEFAULT NULL,

	proxied          BOOLEAN    NOT NULL DEFAULT 0,
	flags            VARCHAR(1) NOT NULL DEFAULT '',  -- ONE OF F
	quantity         INTEGER    NOT NULL DEFAULT 0,
	quality          VARCHAR(2) NOT NULL DEFAULT 'G', -- ONE OF M/NM/EX/VG/G/P
	collection_id    UUID       NOT NULL,

	FOREIGN KEY (print_id)      REFERENCES prints      (id),
	FOREIGN KEY (collection_id) REFERENCES collections (id)
);

CREATE TABLE IF NOT EXISTS sessions (
	id   INTEGER NOT NULL PRIMARY KEY,
	data TEXT NOT NULL
);
