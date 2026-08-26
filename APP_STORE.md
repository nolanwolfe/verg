# Verg — App Store listing copy

Everything that goes in App Store Connect. Engineering QA lives in
`RELEASE_NOTES_2.2.md`; this file is the words.

All of it is written against `VOICE.md` and grepped clean: no exclamation
marks, no questions, no emoji, one person addressed directly, "The Golden
Age" in full with the article, and none of the banned streak / journey /
unlock / level / wellness vocabulary. No first-person plural anywhere — the
guide speaks to the writer, never as a company.

---

## Promotional text — 150 / 170

Written for traffic arriving from Instagram and TikTok, which wants a
different line than App Store search does. Someone who found Verg by
searching needs to be told what it is. Someone who just watched a candle burn
next to a notebook already knows — they need the tap closed.

The whole point of this field is that it updates without shipping a build, so
run one for a week, swap, and keep whichever moves installs.

**Running now:**

> Ten minutes on paper instead of scrolling. Light the candle, write until the bell, keep the page. New in 2.2: the archive, and a lock for the journal.

Now carrying the 2.2 news in its back half. The field updates without a
build, so drop the version clause once the release stops being new and the
line reverts to the evergreen hook.

The hook is aimed at where the person is standing. They are mid-scroll when
they tap through, and this is the one line in the listing that names that.
The app already frames the trade this way after every session — "you wrote
for twelve minutes instead of scrolling" — so it is the product's own
sentence, moved to the front. It is a promise, not a scolding, and it has to
stay on that side of the line.

**If the trade framing reads as a rebuke to someone who just came from a
feed, swap to the ritual stated plainly:**

> Light a candle. Set the phone face down. Write on paper until the bell. Capture the page, and Verg keeps it.

**Or lead with the object, which is what the videos are actually selling:**

> Your own handwriting, kept. Light a candle, set the phone face down, and write on paper until the bell.

Deliberately absent: the three-day trial. This field's job with social
traffic is the install, and the offer has its own screen at the seventh page.
Spending the hook on a discount buys a worse install.

---

## Description — 1998 / 4000

The first three lines show before "more", so they carry the whole pitch on
their own. Only what Verg is, in the active voice — the owner's direction for
2.2: never define the app by what it is not.

```
Verg is a journal you write by hand.

Light a candle. Set the phone face down. Write on paper until the bell. Photograph the page, and Verg keeps it.

This is Verg. A candle, paper, a bell, and your own handwriting.

THE RITUAL

Light the candle. It burns on screen for five minutes, ten, fifteen, or a length of your own.

Set the phone face down. The screen dims itself. Ambient sound if you want it: rain, a fireplace, a stream, eight more.

Write until the bell. On paper, in your own hand, at whatever speed your hand goes.

Photograph the page. Verg keeps it, dated, in your journal.

WHAT IT KEEPS

Your pages, in order, in your own handwriting.

History — a full year at a glance, one square a day, deeper gold where you wrote more. A missed day means the candle went out. You light it again.

Time reclaimed — the minutes you spent writing instead of scrolling, this week and all time.

Books. Finish a journal and it becomes a book on your shelf. Name it, choose its cover, write a line to remember it by.

THE ORACLE

Eighty questions to write toward when the page is blank. Short ones, each a door. Swipe to draw another, then commit to the one you want. Write your own and keep them in folders.

YOURS

Every page lives on your phone, in your own hand, and stays there. Lock the journal behind Face ID or a code of your own, for a phone that gets handed around. Verg guides the ritual and keeps the record. The writing is yours.

FREE, AND THE GOLDEN AGE

Writing is free, always. Save as many pages as you like, and your last seven days stay open to read.

The Golden Age opens the whole archive, every stat, the scripts, ambient sound, custom session lengths, and one relight a week when a day gets away from you.

$7.99 a month, or $59.99 a year with the first three days free.

Your pages stay yours, on your phone, waiting.

---

Named for Virgil, who walked Dante up the mountain.

Terms: https://nolanwolfe.github.io/verg/terms
Privacy: https://nolanwolfe.github.io/verg/privacy
```

---

## What's New in This Version — 2266 / 4000

```
The archive, rebuilt — and a lock for the journal.

ARCHIVE
A new tab holding the whole record of your writing: this year and every year before it, your finished books, and the numbers underneath — time reclaimed, total pages, longest run.

HISTORY
A full year at a glance, one square a day, deeper gold where you wrote more. Switch to a month calendar in Settings if you'd rather read it that way. A missed day means the candle went out. You light it again.

LOCK APP
A passcode on the journal, for a phone that gets handed around. Four digits or a code of your own, opened by Face ID or Touch ID where the phone has it. Settings, then App, then Lock App. The code itself is never stored — only a salted hash of it, in the Keychain, on this device alone.

THE PAGE
Pages are portrait now, the shape of the page you actually write on. Photographs are kept whole and framed for the screen, so what fell outside the viewfinder is still there. Frame the shot yourself before you save it.

THE ORACLE
Eighty questions to write toward when the page is blank. Swipe to draw another, then Select Guidance to commit to it. Write your own, keep them in folders, change them whenever. Or take no script at all — that is a choice, not a missing setting.

BOOKS
Finish a journal and it becomes a book on the shelf. Rename it, choose from twenty-one cover colours, and write a line to remember it by.

LIGHT AND DARK
Verg opens light now. Pin it either way in Settings, then Appearance.

THE CAMERA
A faster shutter, and close-up focus is fixed: hold the phone over the page and it comes sharp. Tap to focus, zoom, and a light for a dark room.

ALSO
- Ambient sound while you write: eleven tracks
- Five, ten, or fifteen minutes, or set your own
- Five more minutes when the bell comes too soon
- Pinch to zoom any page, swipe down to close
- A faster journal, however many pages you have
- New onboarding, ending in the honest arithmetic of a year at your pace

FREE, AND THE GOLDEN AGE
Writing and saving pages is free, always, with no account. Your last seven days stay open. The Golden Age opens the whole archive, the stats, the scripts, ambient sound, custom session lengths, and a weekly relight. $7.99 a month or $59.99 a year, with the first three days free on the year.
```

---

## Keywords — 100 / 100

```
diary,handwriting,notebook,bullet,habit,tracker,streak,focus,detox,screen,time,offline,private,daily
```

Deliberately excludes every word already in the app name — the name is now
"Verg - Journal on Paper", so "journal" and "paper" are both indexed for free
and spending keyword characters on them buys nothing. That freed eleven
characters, which went to "bullet" and "tracker".

Neither of those is a word Verg would use. They are there because Apple
builds search phrases by combining tokens across the name and the keyword
field, and "journal" is in the name: "bullet" reaches "bullet journal",
"tracker" reaches "habit tracker". "screen" and "time" are separate entries
for the same reason — as the single token "screentime" they match nobody
searching "screen time".

"streak" is the one entry that contradicts VOICE.md, which bans the word
outright. Keywords are never rendered to a user, so the ban does not reach
them, but the tension is worth recording rather than discovering later.

---

## Notes on the copy

**"until the bell", not "until it burns out".** `VOICE.md` §5 still records
the 2.2 headline as "Light a candle. Write until it burns out." That predates
the in-app rule that a candle going out is what a *missed day* means, so the
phrase overloads the metaphor. The store copy follows the app; §5 is the
thing that should be corrected.

**The Oracle is eighty, not twenty-four.** The previous draft said
twenty-four, which was true when it was written. `WritingPrompt.builtInTexts`
now holds eighty, and they are all questions rather than the mixed statements
they were. Counted from the file, not remembered.

**The page format is described, not measured.** The copy says pages are
portrait and photographs are kept whole; it never names a ratio. 3:4 can
change again without the listing going stale, which is the same property the
storage change bought in the app.

**The description states only what Verg is.** An earlier draft led with
refusals — no text field, no advice — and the owner's call for 2.2 is the
opposite: active statements, zero negation. The contrast with other journaling
apps is carried by what the ritual is ("a candle, paper, a bell, and your own
handwriting") rather than by a list of absences. The draft greps clean for
no / not / never / nothing / without.

**The lock is in the listing now.** It shipped in 2.2 and the previous draft
predates it. It earns a line in the description as well as the release notes,
because "will my handwriting stay private" is the objection that stops people
photographing a journal at all — the description answers it where someone
deciding will actually read it.

**Every number was re-read from the source for this release, not carried
over:** 80 built-in scripts (`WritingPrompt.builtInTexts`), 21 cover colours
(`BookCoverView.palette`), 11 ambient tracks (`AudioService.AmbientSound`),
5/10/15-minute presets plus custom, a 7-day free window
(`SessionGatingService.freeArchiveWindowDays`), one relight per rolling 7 days
(`CandleRelight`), $7.99/month and $59.99/year with 3 days free
(`VergProducts.storekit`).

**The prices come from the StoreKit configuration, which is not the store.**
`VergProducts.storekit` is what the simulator reads; App Store Connect holds
the real ones. They agree today. If a price is changed in Connect, this file
and the description are both wrong until someone edits them.
