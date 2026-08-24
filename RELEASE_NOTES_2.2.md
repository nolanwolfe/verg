# Verg 2.2 — Release Notes

## Promotional text (App Store, 170 characters max)

Updatable without a new build, so this is the line to change if the pitch
moves.

> Light a candle. Put the phone down. Write until the bell. Photograph the page — your own handwriting, kept.

*107 characters.*

Alternates, same voice, if a shorter line reads better in the listing:

> Pen, paper, ten minutes. Light a candle, write until the bell, and photograph the page.

> A journal you write by hand. Light a candle, set the phone face down, and write until the bell.

## What's New in This Version (1819 / 4000 characters)

```
The archive, rebuilt.

ARCHIVE
A new tab holding the whole record of your writing: this year and every year before it, your finished books, and the numbers underneath — time reclaimed, total pages, longest run.

DAYS LIT
A full year at a glance. Brighter squares are the days you wrote more. Switch to a month calendar in Settings if you'd rather read it that way. A missed day means the candle went out. You light it again.

BOOKS
Finish a journal and it becomes a book on the shelf. Rename it, choose from twenty-one cover colours, and write a line to remember it by.

THE ORACLE
Twenty-four scripts to write toward when the page is blank. Write your own, keep them in folders, change them whenever. Or take no script at all — that is a choice, not a missing setting.

LIGHT AND DARK
Verg follows your phone, or you can pin it to one. Settings, then Appearance.

THE CAMERA
Close-up focus is fixed: hold the phone over the page and it comes sharp. Tap to focus, zoom, and a light for a dark room. Every page is saved in the same frame now, whether you photograph it or choose it from your library.

TIME RECLAIMED
After the bell, the minutes you spent writing instead of scrolling.

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

### Notes on the copy

Written against VOICE.md: no exclamation marks, no questions, no emoji, one
person addressed directly, "The Golden Age" in full with the article, and
no streak, journey, unlock, or level language. Grepped clean.

Two deliberate calls:

- **"until the bell", not "until it burns out".** VOICE.md §5 still records
  the 2.2 headline as "Light a candle. Write until it burns out." That
  predates the in-app rule — a candle going out is what a *missed day*
  means, so the phrase overloads the metaphor. The store copy follows the
  app, and §5 should be corrected rather than the copy matched to it.
- **The page format is described, not measured.** "Every page is saved in
  the same frame" is true whichever aspect ratio it settles on, so the copy
  does not need rewriting if the format changes before submission.

Every number in the copy was checked against the source: 24 built-in
scripts, 21 cover colours, 11 ambient tracks, a 7-day free window,
$7.99/month, $59.99/year, 3 days free.

## QA before submission

### Covered by `VergUITests` — run `xcodebuild test -only-testing:VergUITests`

Twenty tests drive the real app and attach a screenshot of every state, so
these no longer need a person:

- Every tab renders its own content, in Light and in Dark
- Onboarding: all six screens in order, and Skip going straight into the app
- Appearance picker selects and persists; History switches the Archive
  between heatmap and month grid
- A script can be written, saved, and then edited
- The Oracle sheet and the duration picker open
- The Sound pill on Write and the Sound row in Settings are one switch
- The journal grid draws pages; the fullscreen viewer opens on the tapped one
- Book detail opens, and the rename/colour sheet reaches its 21 swatches
- Tapping a locked page opens the paywall *and* names the page
- The paywall opens from The Golden Age
- The timer screen renders and counts down, in both themes
- The achievements ladder renders below the fold

### Still needs a physical device

Everything below touches hardware, money, or real time — none of it can be
exercised in a simulator.

- [ ] **Camera.** Close-up focus on a page: the app now asks for the virtual
      multi-camera device so iOS can drop to the ultra-wide for macro. Check a
      page fills the frame *and* comes sharp. Tap-to-focus ring appears. The
      1x/2x selector switches lenses. The torch lights and goes out when the
      screen closes. `CameraView` compiles out to a photo-picker stub in the
      simulator, so none of this has ever run outside a device.
- [ ] **Page format.** Pages are landscape 3:2 now, and the viewfinder is
      masked to it. Find the angle and distance that frames a spread — an
      upright phone crops to the middle band, which is a real change from 2.1.
- [ ] **Prices and the trial.** The paywall reads RevenueCat at runtime. See
      the two open items below before testing this.
- [ ] **Purchase, restore, and the access code**, against a sandbox account.
- [ ] **Ambient sound** on speaker and headphones; silent switch stops it;
      it does not interrupt music already playing.
- [ ] **Upgrade from 2.1** with a real journal: pages load, legacy images
      migrate in the background, nothing re-runs onboarding.
- [ ] **Relight**, which needs a premium account and moving the device clock.
- [ ] **Notifications** actually fire at the set time.
- [ ] **Reduce Motion**: the paywall flame holds still; the gold sheen on the
      trial badge holds still.

### Two things that are not code

Both were confirmed from the running app tonight and neither can be fixed
here:

1. **Monthly is priced $4.99, not $7.99.** The paywall shows real RevenueCat
   data, and Monthly reads $4.99/mo — identical to Yearly's per-month figure,
   which leaves the yearly plan with no advantage at all. The local
   `VergProducts.storekit` says $7.99 but that file is test-only. Fix in App
   Store Connect.
2. **There is no free trial on the real product.** The app logs
   `[Trial] offer=nil eligible=false storeKitTrial=nil productFound=true` —
   StoreKit found `Verg_Yearly` and reports no introductory offer on it. The
   trial exists only in the local test file. Configure it in App Store
   Connect, or the trial badge will never appear.

