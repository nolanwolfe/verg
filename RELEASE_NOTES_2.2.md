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
- **New onboarding** — five quick screens (what Verg is, the ritual, your
  weekly commitment, an honest projection of a year at that pace) leading
  into your first session — not a cold paywall out of nowhere.
- **Write as much as you want, always free** — the free tier now gates
  saving extra pages, not starting sessions.
- **Weekly goal milestones** — commit to 3, 5, or 7 days a week during
  onboarding and get celebrated for keeping the pace, alongside the
  existing page-count milestones.
- **Friendlier Stats tab** — warmer visuals, same numbers, now with your
  weekly-goal progress alongside streak/pages/milestones.

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
- [ ] Free-tier gating: fresh install, complete a session and save the
      photo — succeeds. Complete a second session and try to save →
      paywall appears; subscribing completes that save automatically,
      dismissing without subscribing leaves you on the retake/use-photo
      screen (page not lost, just not saved yet). Starting sessions is
      never blocked, with or without saved pages
- [ ] Trial: paywall shows a free-trial disclosure on Yearly only; Monthly
      shows price with no trial copy (requires the ASC change below to be
      live to see real data — local StoreKit config already updated)
- [ ] Weekly goal milestone: set a commitment in onboarding, seed enough
      sessions across enough distinct days in a completed week to meet it
      (or wait a week on device), confirm the celebration appears after a
      later session's save, sequenced after any page-count milestone and
      before the Time Reclaimed reveal — never both milestones on screen
      at once. Stats tab's Weekly Goal card only appears once a commitment
      is set and shows correct progress
- [ ] Rating prompt: fires at most once per app session total, from
      whichever of the two triggers (onboarding, or the bell on exact day
      3 of a streak) happens first — never on cold launch, never twice
- [ ] Stats tab: warm glow/gradient icons render correctly in the
      carousel; existing numbers (streak, pages, longest streak, Time
      Reclaimed, milestones) are unchanged from before the reskin

## App Store Connect / RevenueCat — manual actions needed

- [ ] Remove the free introductory offer from the **Verg_Monthly**
      subscription (trial is yearly-only now) — both in App Store Connect
      and in the RevenueCat offering/package config
- [ ] Confirm **Verg_Yearly** still has its introductory offer configured
      as before — no change needed there, just confirming
- [ ] Verify existing subscribers on Monthly keep their access — this
      should be automatic (RevenueCat's `premium` entitlement checks stay
      entitlement-based, not product-ID-based, and existing subscriptions
      aren't cancelled by removing the *offer* on the product), but worth
      a spot-check against a sandbox account that already redeemed the old
      monthly trial

## Version

- Marketing version: 2.2
- Build: 11
