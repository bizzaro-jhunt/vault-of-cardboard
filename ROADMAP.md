Vault of Cardboard Roadmap
==========================

This is (roughly) what I want to do with VCB, in case anyone is
interested in helping out / contributing / beta-testing / etc.

1. Improve the Import Process
-----------------------------

Right now, the import process consists of a single-shot import,
driven by a textarea that is incredibly unforgiving.  If any
single line of the input data is incorrect, malformed, or
represents an unknown or non-existent card (print), the whole
import fails and the player is left with no _iterative_ process of
refinement short of trying again.

The import process also currently only accepts VCB's own
semi-custom format, even though people may already have access to
their entire collection in a different format like TCGPlayer's
scanning app plain text export.

**What I'd Like To See:**

1. Support for other formats, along with a mechanism to
   automatically detect what format is in use, and to override
   that logic when needed.  Think "vim modeline".

2. An interactive "repair" process for an import.  Often, imports
   fail for a few handful of reasons: typos, incorrect set
   identification, ambiguous card selection ("which Swamp?").
   Instead of halting the import outright, or making an uninformed
   guess, it would be nice if the importer could pause, and ask
   the player for clarification.

   The following proposed interactions all play out with VCB
   performing a laxer, more heuristic search and asking the player
   to pick their card(s).  Note that even in the event of a single
   match in the search results, the importer _must still ask the
   user_, since it is deviating from instruction.

   In the case of bad sets, search for the title of the card,
   without the set designator.  For example "Charge" is a DOM card
   only; it does not exist elsewhere.  If a player tries to import
   "Charge" from GRN, the importer can do a quick search for cards
   named "Charge" (probably case-insensitive) and ask the player
   if they meant the DOM print.

   For typos, we have to be a little more clever in the search
   logic, but the idea is the same -- perform a _looser_ search
   (perhaps by spell-checking the card name, or dropping words),
   and present the results as candidate cards.

   For ambiguous cards (i.e. GRN's guild gate lands), the set and
   title are correct, but there are multiple art variations, each
   with their own collector number.  As before, show all matching
   variants and let the player pick the one that looks like their
   card.

   There is one small(ish) edge case that needs to be handled
   deftly here, vis-a-vis art variants.  Very few people are going
   to supply collector numbers in the import (although the VCB
   format does need to support doing so).  Especially for basic
   land imports, I expect to see a lot of "40x M19 Forest" -- the
   chances that _all forty_ of these cards are the same art is
   pretty slim, so the prompting interface needs to let the player
   divide up their import quantity between all variants.  This
   probably only makes sense for set/name matches, not typos or
   other import errors.

3. An **iterative** collection modification mechanism.  I do not
   expect most people approach card infusion by editing a giant
   text blob and "re-importing" the whole collection.  Especially
   if you're cracking packs, cards are being added to the
   collection, usually 1x each, a few dozen at a time.  It would
   be great if we could leverage the search feature of the main
   VCB UI to accommodate collection modifications.

   It would play out like this: the player needs to add an
   Abnormal Endurance from M19 to their collection, so they go to
   the search box and type `Abnormal` and hit enter.  VCB shows
   them a bunch of this reprint.  They find and pick the art that
   matches, for the M19 set, and access the big card view.  Right
   there on the modal dialog is a button or spinbox or something
   that lets them add one (or more!) to their collection.

   This does have the added overhead of recaching their entire
   collection once per add, if done naively.  Something to watch
   out for.

If the collection- (and later deck-) management experience is
smooth, I expect people will appreciate VCB more.  I know I will.


2. Improve the Onboarding Experience
------------------------------------

VCB has a terrible onboarding experience.  What we need:

1. Self-service signup!  Right now, I create all the accounts
   manually and communicate passwords to people.  To get this
   thing off the ground, people are going to need to be able to
   sign up.  This means email support, a signup form, etc.

2. A Home Page.  Once you've logged into VCB, there's no clear
   direction on what to do next.  I think the "X/Y steps
   completed" style of onboarding works well here, since most
   players need to (at the very least) import their collection.

   A home page, tailored to the player, can provide them this
   jumping off point ("I see you don't have any cards yet!"), as
   well as provide interesting stats _about_ the collection,
   including:

     - Total "value" of collection
     - Set / color / type composition
     - Most expensive card
     - etc.

   When we integrate deck management, this would be a good place
   to put the deck list / links.


3. Card Annotation
------------------

Some sets of cards logically go together, but don't share an
easily-queried set of common attributes.  For example, tap lands
can kind of be approximated by `type:"Land" and +tapped`, and
pain lands by `type:"Land" and +damage`.  It would be far better,
however, if we could annotate the card with a tag, like `tapland`,
and then query for all things so tagged, i.e. `tag:tapland`.

The design question that still has to be answered is whether or
not we make these global or private / per-user.  The former
requires an ACL system, and partitions the users into "mods" and
"non-mods".  The latter breaks search referential integriy; the
same query may return wildly different results depending on who is
logged in.  Admittedly, we already do this for `own:...`, but that
is more clearly a per-user query filter.


4. Sub-Collection (Deck + Buy) Management
-----------------------------------------

The player in me wants to build decks with this tool.  The
collector in me wants to keep track of buy dates to know when a
card came into the collection.

These are both specializations on collection management.  A "deck"
is just a sub-collection with constraints (format, number of
cards, etc.), and a buy is just a sub-collection with additional
metadata (buy date, notes, name, etc.)
