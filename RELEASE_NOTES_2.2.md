# Verg 2.2 — Release Notes

## App Store "What's New" draft

**Verg 2.2 — Your journal, leveled up.**

- **Books** — finish a journal, give it a name, and start a fresh one. Your
  collection lives on a shelf in the Journal tab.
- **Milestone rewards** — celebrate 10, 25, 50, 100, 250, 500, and 1,000 pages
  with a little fire.
- **New Stats tab** — swipe through your streak, total pages, longest streak,
  and milestone progress.
- **Ambient sounds (Pro)** — rain, fireplace, or deep focus while you write.
- **+5 more minutes** — candle burned out but you're still flowing? Relight it.
- **Pick your session length right on the home screen.**
- **Sharper page photos** — tap to focus, and close-up focus is fixed.
- **Pinch to zoom** — zoom and pan any page in the fullscreen viewer, swipe
  down to dismiss.
- **Faster journal** — smoother scrolling and instant page browsing, even with
  hundreds of pages.
- **Time Reclaimed** — see how many minutes you spent writing instead of
  scrolling, today and all-time, on the Stats tab.
- **New onboarding** — the Dante/Virgil epigraph, then five quick screens
  (what Verg is, the ritual, your weekly commitment, an honest projection
  of a year at that pace) leading into your first session and the paywall.
- **Write and save as much as you want, always free** — the last 7 days
  of pages, days lit, and the calendar are free forever, no account.
  **The Ascent** unlocks your full archive, Stats, prompts, ambient
  sound, custom session length, and relights.
- **Days lit, not streaks** — a missed day means the candle went out, not
  a "streak broken." Ascent subscribers get one relight a week: a missed
  day doesn't have to put the candle out, marked distinctly on the
  calendar, never shown as if you wrote.
- **Seven Terraces** — quiet milestones at 7, 14, 30, 60, 100, 200, and
  365 days lit. No badges, no points — a marked day and one line of text.
- **Weekly goal milestones** — commit to 3, 5, or 7 days a week during
  onboarding and get celebrated for keeping the pace, alongside the
  existing page-count milestones.
- **Friendlier Stats tab** — warmer visuals, same numbers.

## QA checklist before submission (needs a physical device)

- [ ] Camera: tap-to-focus ring appears; close-up page shots come out sharp
      (continuous AF + near-range restriction are new)
- [ ] Ambient sounds: audition all three loops on speaker + headphones
      (synthesized — replace with licensed recordings later if desired)
- [ ] Existing install upgrade: 117-page journal loads instantly, no
      onboarding replay, milestones show 10/25/50/100 already unlocked with
      no celebration popup
- [ ] Legacy image migration: on first launch after upgrade, pre-2.2 photos
      are re-encoded to 2048 px in the background (~10-20 s for 117 pages).
      After it finishes, fullscreen swiping through old pages is smooth and
      photos still look sharp. Kill + relaunch mid-migration → it resumes
- [ ] Fullscreen viewer with 100+ pages: opens instantly (thumbnail shows
      first, sharpens to full-res), fast swiping stays smooth, memory stays
      flat in Xcode gauge
- [ ] Pinch-to-zoom: pinch in/out and pan on a page, double-tap toggles
      zoomed/fit, swipe-down-to-dismiss works when unzoomed and doesn't
      fight panning when zoomed in, page-swipe still works at zoomScale 1
- [ ] Finish Journal flow → book appears on shelf, grid resets, pages visible
      inside the book read-only
- [ ] Timer end → "+5 more minutes" relights the candle; notification
      reschedules
- [ ] Pro gating: Ambience row locked for free users → paywall; unlocked for
      subscriber / access-code accounts
- [ ] Time Reclaimed: after a session (once any milestone celebration
      clears), a full-screen reveal reads "You wrote for N minutes instead
      of scrolling" (or the running daily total on a 2nd+ same-day
      session) — big number, spring-in, haptic, "Continue" returns home.
      Skipping the photo or cancelling the session shows neither milestone
      nor this reveal. Background the app mid-session and confirm the
      backgrounded minutes are NOT counted (compare the reveal/Stats total
      against a stopwatch of foreground time only). Stats tab shows a
      correct This Week total + delta vs. last week + streak, and an
      all-time total in the carousel. Weekly Recap toggle in Settings is off
      by default and, when enabled, requests notification permission
- [ ] Fresh install → onboarding: 5 steps advance correctly, commitment
      picker defaults to 5 days and reflects taps, projection numbers match
      the chosen pace (e.g. 5 days → 260 pages / 43 hours), rating-prompt
      screen's Continue hands off to the paywall. Skip from any screen goes
      straight into the app with no paywall shown
- [ ] Free-tier gating (NEW model — supersedes the old photo-count QA
      item above, which no longer applies): writing and saving pages is
      always free and unlimited. A page dated within the last 7 days is
      fully viewable for free; a page older than 7 days renders dimmed
      with a lock badge in both the Journal grid and inside Books —
      never disappears, tapping opens the paywall. Subscribing makes
      every existing page viewable immediately, nothing was ever deleted.
- [ ] Stats gating: Days Lit card and the calendar are visible/free with
      no account. Every other carousel card (pages, longest run, Time
      Reclaimed, weekly goal, milestones) renders redacted with a lock
      overlay — reserves its spot in the swipe, tap opens the paywall.
      This Week card below the carousel is replaced by a locked prompt
      card for free users.
- [ ] Custom timer duration: picking anything other than 10 minutes (in
      both Home's and Settings' duration pickers) prompts the paywall
      for free users instead of applying; premium users can pick freely.
- [ ] Relight (needs a premium test account + manipulating the device
      clock, or waiting real days): miss exactly one day within 7 days of
      the last relight used → candle stays lit, that day shows a ringed
      amber dot on the calendar (never a solid "written" dot), days-lit
      count does NOT increment for the relit day. Miss two days in a row,
      or a second isolated day within 7 days of the first relight →
      candle goes out, days-lit resets to 0. Free accounts: any missed
      day always resets to 0, no relight ever applied.
- [ ] Days lit rename: Home screen, Stats, and Settings all say "days
      lit" / "candle went out" — confirm no leftover "streak" copy
      anywhere in the UI (comments are fine, only user-visible strings
      matter)
- [ ] Seven Terraces: reach 7 days lit (or seed test data) → after the
      bell, a small italic line appears at the top of the timer screen
      for a few seconds and fades on its own — never a full-screen
      takeover, never blocks returning to Home
- [ ] Onboarding epigraph: first screen is the Dante/Virgil quote in an
      italic serif font (confirm it's the ONLY serif screen in the app),
      skippable, and never appears again anywhere else after onboarding
- [ ] Trial: paywall shows "Start Free Trial" and the trial disclosure
      only when Yearly is selected; switching to Monthly changes the CTA
      to "Continue" with plain auto-renewal copy, no trial language
      (requires the ASC change below to be live to see real trial data —
      local StoreKit config already updated)
- [ ] Ambient sound: still plays correctly during a session (rain/
      fireplace/deep focus), now silenced by the physical mute switch —
      confirm flipping silent mid-session stops it; confirm it still
      doesn't interrupt music/podcasts already playing
- [ ] Weekly goal milestone: set a commitment in onboarding, seed enough
      sessions across enough distinct days in a completed week to meet it
      (or wait a week on device), confirm the celebration appears after a
      later session's save, sequenced after any page-count milestone and
      before the Time Reclaimed reveal — never both milestones on screen
      at once. Stats tab's Weekly Goal card only appears once a commitment
      is set and shows correct progress (and only once Stats is unlocked)
- [ ] Rating prompt: fires at most once per app session total, from
      whichever of the two triggers (onboarding, or the bell on exact day
      3 of a lit candle) happens first — never on cold launch, never twice
- [ ] Stats tab: warm glow/gradient icons render correctly in the
      carousel; existing numbers (days lit, pages, longest run, Time
      Reclaimed, milestones) are unchanged from before the reskin

## App Store Connect / RevenueCat — manual actions needed

**Pricing (per the 2026-08-22 business-model brief — $7.99/mo, $59.99/yr):**
- [ ] Update **Verg_Monthly** price to $7.99/month in App Store Connect
- [ ] Update **Verg_Yearly** price to $59.99/year in App Store Connect
- [ ] Set/confirm **Verg_Yearly**'s introductory offer is a **3-day free
      trial** specifically (not the 30-day one the code's fallback text
      used to imply) — update both ASC and the RevenueCat package
- [ ] Remove **Verg_Monthly**'s introductory offer entirely — Monthly
      gets no trial, in both ASC and RevenueCat (this part was already
      flagged and the local StoreKit test config already reflects it)

**Weekly SKU — code has never known about this product:**
- [ ] Stop offering it for new purchases in App Store Connect (mark it
      not-for-sale / remove from the current subscription group's
      available list) — do NOT delete it
- [ ] Confirm in RevenueCat that its entitlement mapping to `premium` is
      untouched, so existing weekly subscribers keep access — the app's
      entitlement check is already product-ID-agnostic (`customerInfo
      .entitlements["premium"].isActive`), so no code change was needed
      or made here

**"Pro Access" SKU — genuinely unknown from here:**
- [ ] I could not find this referenced anywhere in the codebase or the
      local StoreKit config, and have no way to inspect App Store Connect
      or the RevenueCat dashboard from this environment. You'll need to
      look it up yourself (App Store Connect → your app → In-App
      Purchases/Subscriptions, or RevenueCat → Products) and decide
      whether to retire or repurpose it — I can't tell you what it was.

**Grandfathering — how it's handled:**
- The `premium` RevenueCat entitlement is the only thing the app checks
  (`PurchaseService.isSubscribed`) — never a specific product ID. As long
  as Weekly/Monthly/Yearly (old or new price) all stay mapped to that one
  entitlement in RevenueCat, every existing subscriber keeps full access
  automatically, regardless of what changes in ASC pricing or offer
  config. No code change was needed for this; it was already true before
  this pass. Worth a spot-check against a sandbox account on each
  existing SKU after the ASC changes land, but not expected to break.

## Version

- Marketing version: 2.2
- Build: 14
