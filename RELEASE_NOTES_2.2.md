# Verg 2.2 — Release Notes

## App Store "What's New" draft

**Verg 2.2 — Light a candle. Write until it burns out.**

- **Library** — a new tab that holds the whole record of your writing:
  year-by-year totals, finished books, every stat, and the full
  milestone ladder out to one million pages.
- **Days lit heatmap** — a full year of writing at a glance, in ink.
  Scroll back through the months; brighter cells mean more pages that day.
- **Books, customized** — rename any book and choose its cover color.
  Books live on the Library tab now; the Journal tab is just your current
  journal.
- **Milestones** — the whole ladder listed plainly: 10 pages to
  1,000,000. Earned rows stay lit; the next one shows how far you have to go.
- **Time Reclaimed** — see the minutes you spent writing instead of
  scrolling, this week and all-time.
- **Ambient sounds (The Golden Age)** — rain, fireplace, or deep focus while you write.
- **+5 more minutes** — candle burned out but you're still flowing? Relight it.
- **5, 10, or 15 minute sessions**, or set your own length.
- **Sharper page photos** — tap to focus; close-up focus is fixed.
- **Pinch to zoom** — zoom and pan any page; swipe down to dismiss.
- **Faster journal** — smooth scrolling and instant page browsing, even
  with hundreds of pages.
- **New onboarding** — the Dante/Virgil epigraph, then five quick screens
  ending in an honest projection of a year at your pace.
- **Write and save as much as you want, always free** — the last 7 days
  of pages, days lit, and the heatmap are free forever, no account.
  **The Golden Age** unlocks your full archive, stats, prompts, ambient
  sound, custom session length, and relights ($7.99/month or $59.99/year,
  3-day free trial on yearly).
- **Days lit, not streaks** — a missed day means the candle went out,
  not a "streak broken." The Golden Age includes one relight a week, marked on
  the calendar as its own thing — never shown as if you wrote.
- **Quiet milestones for days lit** — marked with a line of text after
  the bell. No badges, no points.

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

