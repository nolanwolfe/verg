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
- [ ] Trial: paywall shows "Start 3 days free" and the trial disclosure
      only when Yearly is selected and the subscriber is intro-offer
      eligible; switching to Monthly changes the CTA to "Continue" with
      plain pricing, no trial language (requires the ASC change below to
      be live to see real trial data — local StoreKit config already
      updated)
- [ ] Paywall redesign ("The Golden Age," one screen, no scroll): on iPhone
      SE (smallest supported size) every section is visible at once with
      no scrolling — header with animated candle logo, both hero feature
      cards, "Also included" line, both plan rows, CTA button, and the
      Restore/Terms/Privacy footer. Nothing is clipped or pushed off
      screen
- [ ] Reduce Motion: with the system setting on, the paywall's candle
      flame is static (no flicker loop); with it off, the flame flickers
      slowly and calmly (~2-3s loop) — the logo itself never bounces or
      scales, only the flame
- [ ] Trial-ineligible (lapsed subscriber) state: Yearly row shows the
      plain $59.99/year price with no trial line, and the CTA reads
      "Continue" instead of "Start 3 days free" — verify against a
      sandbox account that has previously redeemed the intro offer
- [ ] Restore Purchases (footer link): tapping it actually restores an
      existing subscription and unlocks premium; shows an error state
      when there's nothing to restore
- [ ] Price accuracy: the price shown on each plan row, the Yearly
      per-month equivalence, and the CTA's trial wording all match
      exactly what RevenueCat/StoreKit returns for the real product IDs
      — no hardcoded numbers anywhere in this screen
- [ ] Duplicate price bug (previous build): confirm each plan row shows
      its price exactly once (right-aligned) — not once on each side
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

**Tier rename to "The Golden Age" (2026-08-23):**
- [ ] Update the subscription's **display name** shown to users in App
      Store Connect (and the RevenueCat offering/package descriptions if
      they surface anywhere) from "The Ascent" to **The Golden Age**
- [ ] Leave the **`premium`** entitlement identifier and the
      **Verg_Monthly** / **Verg_Yearly** product IDs exactly as they are —
      the rename is display-only, and changing identifiers would strand
      existing subscribers

**Pricing (per the 2026-08-22 business-model brief — $7.99/mo, $59.99/yr):**
- [ ] Update **Verg_Monthly** price to $7.99/month in App Store Connect
- [ ] Update **Verg_Yearly** price to $59.99/year in App Store Connect
- [ ] Set/confirm **Verg_Yearly**'s introductory offer is a **3-day free
      trial** specifically (not the 30-day one the code's fallback text
      used to imply) — update both ASC and the RevenueCat package
- [ ] Remove **Verg_Monthly**'s introductory offer entirely — Monthly
      gets no trial, in both ASC and RevenueCat
- [ ] In the RevenueCat dashboard, confirm the **`premium`** offering's
      current packages point at **Verg_Monthly** and **Verg_Yearly**
      (exact casing) with the pricing/trial above, before relying on the
      paywall to display them — the paywall reads pricing and trial
      eligibility from this offering at runtime and shows nothing (blank
      price, no trial line) rather than a guess if it isn't configured

**Local dev/testing note (already fixed in code):** `VergProducts.storekit`
had two bugs found while testing this paywall redesign — its product IDs
were lowercase (`verg_monthly`/`verg_yearly`) while `ProductIdentifiers.swift`
expects `Verg_Monthly`/`Verg_Yearly` (case-sensitive), so local StoreKit
testing could never find the products; and it still had the old $4.99 /
$60 / 1-month-trial numbers. Both are corrected to match this brief.
Separately: `PurchaseService`'s `revenueCatAPIKey` is currently a real,
non-empty production key, which makes `isUsingStoreKitTesting` always
`false` — so local StoreKit testing (Xcode's StoreKit Configuration file)
doesn't actually activate right now regardless of the scheme. Testing the
live price/trial text end-to-end requires either a signed-in App Store
sandbox tester or the RevenueCat offering above actually configured.

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

## Voice, Terraces, and Volumes — part one (build 18)

**App Store Connect / RevenueCat manual actions needed for this pass:
none.** Voice rewrite, milestone threshold/copy changes, candle visual
states, the Stats rebuild, and the paywall rename+icon swap are all
client-side — no pricing, product, entitlement, or offering change.
The Volume/PDF-binding feature described in the brief that prompted this
pass (bind the archive at 150 days lit) was explicitly deferred to a
later build at the user's direction — nothing here changes the
Book/Journal data model or adds a premium-gated action beyond what
already existed.

Additional QA items for this build:
- [ ] Voice spot-check: no exclamation marks anywhere in the app (the
      one intentional exception is the share-sheet text in Settings,
      which is addressed to a third party, not the app's own user, and
      was left as-is), no direct questions except the three destructive
      confirmations ("Delete this page?", "Delete this book?", "Finish
      this journal?"), which are deliberately kept as questions
- [ ] Home screen: a brand-new user with 0 days lit sees "Light your
      candle." — a user whose candle previously reached at least 1 day
      and is now back at 0 sees "The candle went out. Light it again."
      instead
- [ ] Milestones: days-lit thresholds fire at 7/14/30/50/75/100/150 with
      plain-number text ("Seven days lit." etc.), no "terrace" language
      anywhere user-visible
- [ ] Candle visual states: Home screen candle looks visibly different
      at 0, 10, 40, and 80+ days lit (shorter, more pooled wax, warmer
      color, steadier flame) — the in-session timer candle during an
      active session is unaffected by days lit, only by session progress
- [ ] Stats tab: fits on one screen with no scrolling on iPhone SE
      (This Week / locked-feature card hidden) and on a standard-size
      iPhone (card shown, calendar unabridged) — all seven weekday
      letters (S M T W T F S) render in the calendar header, locked and
      unlocked carousel cards align identically against the page dots
- [ ] Paywall: title reads "On the Verg of Becoming," header shows the
      real Verg app icon (static, not animated), benefit copy matches
      the new voice

## Version

- Marketing version: 2.2
- Build: 18
