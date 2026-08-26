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

## Description — 2179 / 4000

The first three lines show before "more", so they carry the whole pitch on
their own. Only what Verg is, in the active voice — the owner's direction for
2.2: never define the app by what it is not.

```
Verg is a journal you write by hand, on paper.

The candle keeps the time, then saves it for you, dated, for good.

Ten minutes a day, five days a week. In a year that is 260 pages in your hand and 43 hours off your phone.

WHY PAPER

Your hand moves slower than your thumbs, and slower is the point. A sentence you write by hand is a sentence you thought about.

The phone spends the whole session face down. It holds the candle, counts the time, and waits.

THE RITUAL

Light the candle. It burns on screen for five minutes, ten, fifteen, or a length of your own.

Set the phone face down. The screen dims itself. Ambient sound if you want it: rain, a fireplace, a stream, eight more.

Write until the bell. On paper, in your own hand, at whatever speed your hand goes.

Capture the page. Verg keeps it, dated, in your journal.

WHAT YOU GET BACK

Your handwriting, kept. Every page in order, in your own hand, still yours to read years from now.

Proof you showed up. A full year at a glance, one square a day, deeper gold where you wrote more. A missed day means the candle went out. You light it again.

The hours. Verg counts the minutes you spent writing instead of scrolling, this week and all time.

A shelf. Finish a journal and it becomes a book. Name it, choose its cover, write a line to remember it by.

WHEN THE PAGE IS BLANK

Eighty questions to write toward. Short ones, each a door. Draw another if the first one is not yours, or write your own and keep them in folders.

YOURS ALONE

Every page lives on this phone and stays there. No account, nothing to sign up for.

Lock the journal behind Face ID or a code of your own, for a phone that gets handed around.

Verg guides the ritual and keeps the record. The writing is yours.

FREE, AND THE GOLDEN AGE

Writing is free, always. Save as many pages as you like, and your last seven days stay open to read.

The Golden Age opens the whole archive, every stat, the questions, ambient sound, custom session lengths, and one relight a week when a day gets away from you.

Light the candle tonight, and write one page.

App: https://verg.app/download
Terms: https://verg.app/terms
Privacy: https://verg.app/privacy
```

---

## What's New in This Version — 1441 / 4000

```
Verg opens light, and follows your phone if you would rather. Ambient sound while you write, eleven tracks. Five, ten or fifteen minutes, or a length of your own. Five more when the bell comes too soon. Pinch to zoom any page, swipe down to close. A faster journal, however many pages you have. New onboarding, ending in the honest arithmetic of a year at your pace.

The Archive is new — a tab holding the whole record of your writing: this year and every year before it, your finished books, and the numbers underneath. Time reclaimed, total pages, longest run. A year of history at a glance, one square a day, deeper gold where you wrote more. A missed day means the candle went out. You light it again.

The journal locks now. Four digits or a code of your own, opened by Face ID or Touch ID where the phone has it. Settings, then App, then Lock App. The code itself is never stored.

The Oracle has eighty questions to write toward when the page is blank. Swipe to draw another, then Select Guidance to commit to it. Write your own, keep them in folders, change them whenever. Or take no question at all.

Finish a journal and it becomes a book on the shelf, with twenty-one cover colors and a line to remember it by.

Writing and saving pages is free, always, with no account. Your last seven days stay open. The Golden Age opens the whole archive, the stats, the questions, ambient sound, custom session lengths, and a weekly relight.
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

**Prices are no longer in either field.** The owner cut them. Apple renders
the real in-app purchase prices on the listing itself, so the copy was
duplicating something the store already shows and could only go stale
against. The trade is that the three-day trial now goes unmentioned outside
the paywall — worth revisiting if conversion from the listing is weak.

**The page format is no longer in What's New.** Portrait 3:4 and
whole-photo storage were the largest engineering change in 2.2 and the
owner cut them from the release note. Deliberate: a reader who has not seen
the old format has nothing to compare against, and the benefit is already
described in the listing where it lands on people deciding.

**What's New matches 2.1's register, not a feature sheet.** The live 2.1
note reads, in full: "Fixed crash in the journal archive and improved camera
quality and candle burning flicker." One plain sentence, no headings, no
selling. 2.2 is 177 commits and cannot be one sentence, so what carries over
is the voice rather than the length — plain declarative sentences, and none
of the shouted section headers a release note usually reaches for. The
description keeps its headers, because it is a document someone scans; a
release note is read straight through.

**"Capture the page", not "Photograph the page".** The app's own onboarding
says Capture (`AppStrings.Onboarding.ritualSteps`), and the listing follows
the app. This was fixed once in fd439f4 and silently reverted by the 2.2
rewrite; it is worth grepping for before any future pass.

**The Oracle is eighty, not twenty-four.** The previous draft said
twenty-four, which was true when it was written. `WritingPrompt.builtInTexts`
now holds eighty, and they are all questions rather than the mixed statements
they were. Counted from the file, not remembered.

**The page format is described, not measured.** The copy says pages are
portrait and photographs are kept whole; it never names a ratio. 3:4 can
change again without the listing going stale, which is the same property the
storage change bought in the app.

**The description sells, and the first line does the work.** Three lines
show before "more", so they carry the whole pitch: what it is, the ritual in
one breath, and the payoff. The payoff is the app's own arithmetic — 260
pages and 43 hours — lifted out of the onboarding projection where nobody
browsing the store would ever see it. Both numbers are computed by
`OnboardingProjection` at five days a week, not invented for the copy.

**Selling still means saying what Verg is, not what other apps are not.**
An earlier draft led with refusals and the owner rejected it. "Why paper"
therefore argues from the hand ("a sentence you write by hand is a sentence
you thought about") rather than from a competitor's failings, which also
keeps it clear of the review guideline against disparaging other apps. Three
incidental negations remain and none of them lead.

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
