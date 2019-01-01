Vault of Cardboard
==================

This repository contains the source code and Docker image
definitions for **Vault of Cardboard** an online Magic: The
Gathering card collection manager web application.

It looks like this:

![A Screenshot of VCB - so pretty](docs/screenshot.png)

So You Want an Account, Eh?
---------------------------

Right now, the Vault is running in Limited Alpha mode; It's
available (at <https://vaultofcardboard.com>) to friends who play
/ collection; if you want an account reach out to me.

If there's enough demand from the Internet at large, I'll probably
put registration features into the mix and launch a Beta.  We
shall see.

The VCB Query Language
----------------------

This section describes how to write queries against the Vault.

The simplest of Vault queries consist of single unquoted words
(i.e.: `counterspell`), and quoted strings (i.e.: `"Blur Sliver"`).
These queries match cards based on their names.  The unquoted
variety is case-insensitive, but matches whole words -- `ral`
would match _Ral, Caller of Storms_, but not _Baral, Chief of
Compliance_.

More advanced expressions exist for matching against other parts
of the card.  For example, `color:W` is an expression that matches
cards whose color identity includes white.

Here's a list of all the expression types currently supported by
the Vault interpreter.  Feel free to skim this list upon first
encountering it, and then return once you get to see how
expressions can be combined!

| Expression | How it works                                                    | Example         |
| ---------- | --------------------------------------------------------------- | --------------- |
| cmc        | Match cards based on their converted mana cost.                 | `cmc:2+`        |
| color      | Match cards based on their color identity.                      | `color:UR`      |
| flavor     | Match cards based on the contents of their flavor text.         | `flavor:Niv`    |
| name       | Match cards based on their name.                               | `name:Bolt`     |
| oracle     | Match cards based on the contents of their oracle text.         | `oracle:draw`   |
| own        | Match cards based on how many you have in your collection.      | `own:4+`        |
| rarity     | Match cards based on their commonality / rarity.                | `rarity:mythic` |
| set        | Match cards based on the expansion set(s) they were printed in. | `set:XLN`       |
| type       | Match cards based on their card type.                           | `type:land`     |
| usd        | Match cards based on their current value/price (per Scryfall)   | `usd:<5.25`     |

Several of these typed expressions are so common that VCB has
either a shorthand or keyword notation for them.

| Shorthand | Equivalent to | Example                                                                   |
| --------- | ------------- | ------------------------------------------------------------------------- |
| `=X`      | `rarity:X`    | `=mythic` will find all Mythic Rares.                                     |
| `@X`      | `color:X`     | `@WB` will find dual white/black cards.                                   |
| `+X`      | `oracle:X`    | `+draw` finds cards that have the word "draw" in their rules text.        |
| `owned`   | `own:1+`      | `owned` finds all of your cards.                                          |
| `have`    | `own:1+`      | `have` is an alias for `owned`.                                           |
| `need`    | `own:0`       | `need` finds all of the cards you don't own (which you clearly **need**). |

Note: if you want to match keywords as a name, for instance if you were
looking for _Hour of Need_, you can use the `name:` expression, as in
`name:"Need"`.  (Due to a technical limitation that should be fixed soon,
you do have to quote the value, which means capitalization matters!)

Finally, for anything but the simplest queries, you're going to want to
combine these expressions into larger aggregate expressions.  For these, you
need the _logical operators_: `and`, `or`, and `not`.

`and` works by checking both sub-expressions; if those both match, the
expression as a whole is a match.  `or` considers the whole expression a
match if _either_ sub-expression is a match.  This mirrors how we use the
words "and" / "or" in English.

For example, there are a lot of legendary creatures.  To build a blue / black
commander (EDH) deck,  I need to find an interesting legendary creature who
is both blue and black.  That's two expressions, stitched together with an
`and`:

    type:legendary and color:UB

The `not` operator lets you negate an assertion.  Commander doesn't
generally allow Planeswalkers to serve as Commanders, and since most walkers
are listed as "Legendary Planeswalkers", I need to amend my query to
exclude all mention of the sub-type:

    type:legendary and color:UB and not type:planeswalker

Much better.

In the interest of reducing keystrokes, `!` is an alias of `not`; forgive
me, this is my programmer roots showing.  A nice compact query that takes
advantage of all this terseness is:

    owned and !=common

... which finds all of the uncommons, rares, and mythic rares in your
collection.

Finally, we need to talk about precedence.  Whenever you chain multiple
`and`'s and `or`'s together, you need to consider what you actually mean.
For example:

    owned and =rare or =mythic

The _intent_ behind this query was to find all my rares.  Unfortunately, the
precedence rules of the query language _bind_ the `owned` and `=rare`
sub-expressions together, and then checks the `=mythic` status.  The upshot
is that what I actually get is all of my owned rares, and every mythic rare
ever printed.

I could reword the query to be:

    =rare or =mythic and owned

(in general, `and owned` on the end will almost always do what you want)

Luckily, you can use parentheses to enforce the precedence you want, without
having to reword:

    owned and (=mythic or =rare)

This causes the rarity expressions to be evaluated, and then checked against
ownership status.  Just like math class!

A Query Cookbook
----------------

If you prefer to learn by doing, or just want to try some things
out, this is the section for you.

**What do I own from _Dominaria_?**

    set:DOM and owned

**What red playsets do I own?** (i.e. for standard deck
construction purposes)

    @R and own:4+

**What taplands exist?**

    type:Land and +tapped

**I would like to drool over Zendikar lands please**

    set:ZEN or set:BFZ and type:land and type:basic

or (if you like parentheticals (as I do)):

    (set:ZEN or set:BFZ) and (type:land and type:basic)

**Oh man do I love a good life transfer card!**

    +gains? and +loses?


Developer-y Stuff
-----------------

_Note: If you're not trying to stand up your own Vault of
Cardboard instance, this section is going to be REALLY confusing._

**Vault of Cardboard** is a Perl Dancer application.  It uses a
handful of CPAN modules.  For ease of distribution, the repository
has a [Dockerfile](Dockerfile) that can be used to build a
self-contained docker image.  It does require Internet access and
makes no effort to pin versions of installed modules.

If you just want to run a Vault, you can pull the official
(semi-supported) Docker image, `huntprod/vault-of-cardboard`,
available on Dockerhub:

    docker pull huntprod/vault-of-cardboard

The image exposes port 80, and takes its configuration queues from
a handful of environment variables:

  - `$VCB_IMAGE_ROOT` - The base (URL) of card face and card art
    images.  This defaults to the publicly-readable S3 bucket that
    the official Vault uses.

  - `$VCB_FAILSAFE_USERNAME` - The username to use for creating
    the initial administrator account.  Defaults to `urza`.

  - `$VCB_FAILSAFE_PASSWORD` - a properly bcrypted password hash,
    for the failsafe administrator account.  You can use `vcb
    bcrypt` (`vcb` is included in the repo, under `bin/`) to
    generate this.  The default hash provides access with the
    password `mishra's factory`.

Since containers are ephemeral, and assembling and managing the
data for a Vault is non-trivial, you probably want to mount
volumes for at least a few of the following in-container
directories:

  - `/data` - Contains the SQLite3 database file that holds all of
    the user-generated data (collections, mostly).

  - `/app/dat` - Contains exported collection and card set data,
    which is consumed directly by the front-end interface.
    Re-generating these files can be costly, so you probably ought
    to save them.

  - `/app/cache` - Contains data from previous Scryfall set
    ingestion activities, to avoid pinging Scryfall too much.

To run the docker container, I suggest something like this:

    docker volume create vcb-db
    docker volume create vcb-dat
    docker volume create vcb-cache
    docker run -d -p 8001:80 \
               -v vcb-db:/data \
               -v vcb-dat:/app/dat \
               -v vcb-cache:/app/cache \
               huntprod/vault-of-cardboard

Then, your new Vault will be available on port 8001.
Next, you'll need to ingest some sets from Scryfall, and perhaps
import a collection using the `urza` account:

    export VCB_API=http://localhost:8001
    ./bin/vcb ingest GRN XLN DOM RIX M19
    ./bin/vcb import urza < ~/.mtg/collection.vif

For more details on the VCB import format, see the next section.

Finally, if you are hacking on the Vault, and want to take
advantage of Docker for testing and workflow (which I strongly
encourage), we have **a Makefile!!**  All you need is:

    make

And then run it using the above command.

The VCB Import Format
---------------------

In the future, the Vault will support lots of different import
formats, but for now, it only handles its own format, called VIF
(unimaginatively, that stands for **V**CB **I**mport **F**ormat).

VIF is a line-based format.  Blank lines are ignored, as are Mac-
and Windows-style carriage returns (`\r`).  Comments start at `#`
and continue to the end of the line, and lines consisting of
nothing but spaces and tabs (collectively, "whitespace") are
considered to be blank.

Here's an example VIF file that imports some cards from Dominaria
and Rivals of Ixalan:

    2x DOM Soul Salvage
    1x DOM Slimefoot, the Stowaway
    1x RIX Sun-Collared Raptor
    1x DOM Cold-Water Snapper
    1x DOM Voltaic Servant

The first field is the _quantity_ of cards.  The `x` suffix is
optional.

The second field is the official expansion set designation code,
which is usually three to five letters long.  `DOM` is Dominaria,
and `RIX` is Rivals.

The rest of the line is interpreted as the name of the card.  This
has to be an exact match (currently), and needs to match both in
terms of spelling, and punctuation / capitalization.

VIF does support foil variants, and lets you grade your card
collection if you wish.  This is done by two optional fields that
come between the set code and the name of the card.

    # a plain old regular card.  pfft.
    1x DOM Voltaic Servant

    # oooh SHINY!!!
    1x DOM F Voltaic Servant

    # this one is NEAR MINT, AND it's a shiny.
    1x DOM F NM Voltaic Servant

The valid values for the grade / quality column are:

  - `NM` - Near Mint
  - `M`  - Mint
  - `EX` - Excellent
  - `VG` - Very Good
  - `G`  - Good
  - `P`  - Poor
  - `U`  - Unknown (the default)

_Note: Vault of Cardboard does not currently do too much with
condition, but that may change in the future..._

Contributing
------------

This is an open project, licensed MIT.  If you want to hack on it,
find it useful, want to tweak it, go for it.  Small changes can
just be PR'd directly via GitHub.  For larger changes, I only ask
that you contact me directly, or put in a [GitHub issue][1] to
discuss the scope and direction of the proposed change.

Also, I have a [roadmap](ROADMAP.md) of where I'd like to take
this project in the near term.


[1]: https://github.com/jhunt/vault-of-cardboard/issues
