# Changelog

All notable changes to Verg are logged here as they're made. Dates are
when the change was written, not necessarily released.

## [Unreleased] — build 14 (Dante/Virgil business-model pass)

Freemium restructure, done largely autonomously per "do your best" while
the user was away — see the conversation for the judgment calls made
(relight semantics, mid-week-lapse handling, milestone-track scope cuts).

### Added
- `CandleRelight.swift`: pure, tested logic for the premium "one relight
  per rolling 7 days" mechanic. Automatic (not user-triggered), evaluated
  using current premium status at evaluation time (not historical status
  on the day of the miss). 14 tests covering every scenario asked for,
  including the exact-7-day boundary and a lapsed-mid-week subscription.
- Calendar now renders three day states: written (solid dot), relit
  (ringed amber dot — never shown as written), missed (nothing).
- `Terrace.swift`: Seven Terraces days-lit milestone track (7/14/30/60/
  100/200/365 — the summit). Quiet by design: a small auto-dismissing
  line of text after the bell, no full-screen takeover, no badges.
  Doesn't yet mark the specific day on the calendar — flagged as a known
  gap, not silently skipped.
- Onboarding screen 0: the Dante/Virgil epigraph, the only serif-face
  screen in the app, skippable, never reappears.
- `SessionGatingService.canViewPage(dated:)` — the new gate, replacing
  the photo-count gate from the prior task. Free: last 7 days of pages,
  days lit, the calendar, the ritual itself. Ascent: the rest of the
  archive, Stats (except days lit + calendar), weekly-goal milestones,
  custom timer duration, prompts, ambient sound, relights.
- Locked pages (`PageGridView`) render dimmed with a lock badge — visible,
  never hidden or deleted, tapping prompts Ascent. Locked Stats cards
  render redacted with the same treatment.

### Changed
- **Renamed streak → days lit, throughout** — UI strings and underlying
  model/property names: `UserStats.currentStreak`/`longestStreak` →
  `daysLit`/`longestDaysLit` (JSON keys unchanged for backward compat),
  `StreakService` → `CandleService`, `StreakFlameIcon` → `CandleFlameIcon`.
  Copy shifted to "the candle went out" framing — no more "streak broken."
- Saving a photographed page is unconditionally free again (reverted the
  prior task's photo-count paywall gate) — Ascent now gates *viewing*
  older pages, not saving new ones.
- Ambient audio session: `.playback` → `.ambient` category, so it
  respects the silent switch (a real gap before this pass) — the
  trade-off is it won't survive the user manually locking the phone
  mid-session (no declared background-audio mode), only staying
  foregrounded face-down, which is the app's actual common case.
- Paywall copy sells the archive/stats/relights, not a generic feature
  list; "Start Free Trial" CTA only shows when the *selected* plan
  (not just any plan) actually has a trial — Monthly has none now.
- `GAMIFICATION.md` rewritten: retired the XP/levels/quests/leagues
  roadmap, which directly contradicted the new "no badges, no points,
  gets less interesting over time" rule. Documents the three current
  progression tracks and flags that two of them (page-count, weekly-goal)
  still use pre-this-pass full-screen/badge-grid presentation that may
  want to converge on the Terrace treatment later.

### Known gaps (flagged, not hidden)
- Terraces aren't marked on the calendar yet, only announced after the bell.
- No dedicated Terraces list/detail screen (parallel to `MilestonesView`).
- Paywall is a copy/logic pass, not a full visual rebuild.
- Weekly Recap notification copy/Settings still say "streak" in a couple
  of internal-only places (comments, not user-visible strings) — swept
  the user-visible surface first given time constraints.

## Previous — build 11

### Added
- 5-screen onboarding (what Verg is, the ritual, weekly commitment,
  computed projection, rating prompt) feeding directly into the paywall —
  replaces the old 3-screen flow that never showed a paywall at all.
- `OnboardingProjection`: pure, tested arithmetic for the projection
  screen (days/week → pages/hours a year), computed per commitment.
- Weekly-goal milestone track (`WeeklyGoalMilestone`, `WeeklyGoalTracker`)
  — celebrates 1/4/12/26/52 completed weeks meeting the user's chosen
  days-per-week pace, additive alongside the existing page-count
  milestones. Surfaced in Stats as a "Weekly Goal" card once a commitment
  is set.
- `RatingPromptService`: shared `AppStore.requestReview` trigger
  (`SKStoreReviewController` fallback below iOS 18), fired from exactly
  two places — the onboarding rating-prompt screen, and after the bell on
  day 3 of an active streak. Never on cold launch, never twice a session.
- `ProductIdentifiers.swift` — single source of truth for the
  `Verg_Monthly`/`Verg_Yearly` product IDs.
- Stats tab reskin: warm gradient/glow icon treatment matching the
  milestone and Time Reclaimed reveal screens; friendlier header copy.

### Changed
- **Free tier regated**: writing (lighting the candle, the timer, the
  bell) is now always free and unlimited. The paywall only gates saving a
  page beyond the first free one — previously it blocked starting a 4th
  session entirely.
- Default timer duration is now 10 minutes (was 15), matching the app's
  own pitch copy and the projection math.
- Trial is yearly-only now — Monthly's introductory offer removed (see
  RELEASE_NOTES_2.2.md's manual-actions list for the App Store
  Connect/RevenueCat side of this).

### Removed
- `OnboardingPageView` — the old homogeneous onboarding page template,
  unused after the 5-step rebuild (each step is a bespoke view now; the
  screens don't share a common shape).

## Earlier — build 1–10 (2026-08-22, same day)

Not individually logged (this file didn't exist yet), but for reference,
this build range covers the rest of 2.2: legacy image migration + file
protection, pinch-to-zoom/pan/swipe-dismiss in the fullscreen viewer (plus
a zoom-runaway bug fix), the Time Reclaimed feature (foreground-only
writing-time tracking, full-screen post-session reveal, weekly/all-time
stats), and a real `VergTests` XCTest target (didn't exist before —
`Tests/*.swift` sat unwired to anything).
