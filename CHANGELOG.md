# Changelog

All notable changes to Verg are logged here as they're made. Dates are
when the change was written, not necessarily released.

## [Unreleased] — build 19 (Library redesign, book customization, tab bar)

A new Library tab that carries the whole record of the writing — the
year-by-year ledger, finished books, a GitHub-style days-lit heatmap,
the stat grid, and the full page-milestone ladder out to one million
pages. Journal becomes just the current journal. Books gain rename and
cover-color customization. The tab bar hides on scroll-down and returns
on scroll-up on the Library screen.

### Added — Library
- New **Library** tab (replaces Stats in the tab order: Verg · Journal ·
  Write · Library · Settings). Black-and-white archive aesthetic — the
  only warmth on this screen is what the user's pages earned.
- **Year by Year** ledger: every year of writing with proportional bars
  and page counts.
- **Books shelf** moved here from Journal (see Journal below).
- **Days Lit heatmap**: GitHub-style contribution grid in monochrome ink
  — fixed 11pt cells, horizontally scrollable across the last 12 months,
  anchored to the newest week, month labels riding above the grid and
  Mon/Wed/Fri gutter pinned left. Written days climb white by page count;
  relit days keep their open-ring distinction, never rendered as written.
- **Stat grid**: Days Lit (always free), Total Pages, Longest Run, Time
  Reclaimed, This Week (+delta vs last week), Avg Session, Pages This
  Month, Best Day. Locked tiles redact their value and open the paywall.
- **Milestones ladder** listed in full at the bottom: 10 → 25 → 50 → 100
  → 250 → 500 → 1,000 → 2,500 → 5,000 → 10,000 → 25,000 → 50,000 →
  100,000 → 250,000 → 500,000 → 1,000,000 pages. Earned rows solid white
  with "earned", unearned show "N to go" with a thin progress underline
  on the next threshold.

### Changed — Journal
- Journal tab is now only the current journal: header ("Your Journal"),
  page-count subtitle, and the pages grid. No books shelf.
- Tab order rearranged so Write sits center: Verg · Journal · Write ·
  Library · Settings.

### Added — book customization
- Books can be renamed (40-character cap) and given a cover color from a
  seven-swatch palette (leather default, walnut, oxblood, forest, indigo,
  charcoal, gold-tan). Live cover preview in the customize sheet; also
  reachable from inside a book via Rename & Color.
- `Book.colorIndex` persists through tolerant decoding — existing books
  default to leather and keep their look.
- Long titles truncate cleanly on covers: two lines, auto-shrink, tail
  ellipsis.

### Added — auto-hiding tab bar
- On Library, scrolling down fades/slides the tab bar away; scrolling up
  brings it back. Preference-key offset reader with a top-of-page bounce
  guard. Write and Verg never hide it.

### Fixed
- Heatmap day placement: previous implementation used `LazyHGrid`
  (row-major) fed column-major data — days rendered into scrambled cells.
  Rebuilt as explicit week columns.
- Tapping a book on Library now opens its detail view (page browsing);
  previously it opened the customize sheet directly.

### Changed — timer durations
- Presets are now 5 / 10 / 15 minutes ahead of the custom MM:SS field
  (20-minute preset removed). Default remains 10 minutes.

## [Unreleased] — build 18 (voice, terraces, and volumes — part one)

A defined narrative voice across the app's copy, a revised days-lit
milestone system with no visible tier names, a candle that visually
accumulates instead of naming a status, and a Stats page rebuilt to one
non-scrolling screen. The Volume/PDF-binding feature described in this
brief (bind the archive into a book at 150 days lit) was explicitly
deferred by the user for a later pass — nothing in this build changes
the Book/Journal data model, adds PDF export, or touches
`finishCurrentJournal`. Page-count milestone badges and weekly-goal
milestone tiers were also explicitly left untouched this pass.

### Added — voice
- All user-facing copy reviewed against four rules: imperative and
  direct, no praise for showing up (acknowledge only, no exclamation
  marks), short declaratives with no direct questions, never "I"/"we".
  Touched onboarding, the candle screen, the bell, empty states,
  milestones, missed days, the paywall, settings, and error messages.
- New real estate for the "candle went out" reference copy: the Home
  screen's zero-days-lit state now distinguishes a genuinely new user
  ("Light your candle.") from one whose candle lapsed ("The candle went
  out. Light it again."), using `longestDaysLit` — previously
  indistinguishable, both showed the same generic exclamation.
- Consolidated three independent, drifting copies of the days-lit
  status text (`CandleService`, `HomeViewModel`, `UserStats`, plus dead
  constants in `AppStrings`) into one shared
  `AppStrings.Home.daysLitText(daysLit:longestDaysLit:)`.
- Destructive-action confirmations ("Delete this page?", "Delete this
  book?", "Finish this journal?") were deliberately kept as questions —
  the idiomatic, safest iOS phrasing for something the user must
  explicitly decide — rather than forced into declaratives that could
  read as already-done.

### Changed — milestones
- Days-lit thresholds changed from 7/14/30/60/100/200/365 to
  7/14/30/50/75/100/150. Tier names ("The first terrace," … "The
  summit") replaced with plain stated numbers ("Seven days lit," …
  "One hundred and fifty days lit.") — no vocabulary the user has to
  learn. Surfaced the same way as before: a marked calendar day and one
  quiet line after the bell, no badges.

### Added — the candle changes, not a label
- `CandleDaysLitState` (`CandleView.swift`): four discrete visual states
  keyed to days lit (fresh 0–6, settling 7–29, established 30–74, deep
  75+) — wax height shrinks, wax visibly pools at the base, wax and
  flame color warm, and the flame flickers less erratically at higher
  states. Wired on the Home screen's candle only (the in-session timer
  candle keeps its existing burn-down-only behavior — `progress` and
  `daysLit` are independent dimensions). Fully procedural SwiftUI, no
  new art assets. A fifth "reset with a marker" state for after a volume
  is bound is intentionally not modeled yet — a candle past 150 days
  currently holds at the richest state rather than resetting, since
  binding isn't built.

### Changed — Stats page
- Rebuilt to a single non-scrolling screen (same `GeometryReader`-driven
  discipline as the paywall redesign), replacing the previous
  `ScrollView`. On a compact screen the This Week / locked-feature card
  is the first thing cut — the stat carousel and calendar are the core
  display and always show in full.
- **Fixed a real alignment bug**: `lockableCard`'s wrapper was adding a
  second, identical 28pt bottom padding on top of the one already baked
  into every card (`BigStatCard`/`weeklyGoalCard`/`milestoneCard`) for
  page-dot clearance — every locked card (i.e. most cards, for every
  free user) rendered at 56pt instead of 28pt, visibly misaligned
  against the always-unlocked Days Lit card. Now single-padded
  everywhere.
- **Fixed a second, separate rendering bug**: the calendar's weekday
  header (`ForEach(weekdays, id: \.self)`) silently dropped Thursday's
  and the second Saturday's labels, since `weekdays` contains duplicate
  string values ("S" and "T" each appear twice) and SwiftUI can't give
  duplicate-value views unique identity. Switched to index-based
  identity — all seven weekday letters now render.
- `CalendarView` gained a `compact` mode (smaller cells, tighter
  spacing) used automatically on short screens.
- Corners standardized to 12pt continuous across every Stats card,
  matching the paywall redesign's language (previously 16pt circular).
- Removed the last two exclamation marks in Stats ("All goal milestones
  unlocked!", "All milestones unlocked!") and shortened the locked-card
  overlay copy from "Unlock with The Ascent" to "Unlock to view."

### Changed — paywall
- Renamed "The Ascent" to **"On the Verg of Becoming"** everywhere
  (paywall title, Settings upgrade row, Stats locked-card copy).
- Replaced the animated candle-flame header mark (added in the previous
  paywall redesign) with the real Verg app icon, shown static as a
  small rounded-square icon — its own dark backdrop is contained within
  its own frame, so it reads cleanly against the paywall's light
  background. Static rather than animated since it's raster artwork,
  not a procedural flame.
- Benefit copy tightened to the new voice ("Your full archive, not just
  the last 7 days" / "Every stat. Pages, longest run, time reclaimed").

### Tests
- `TerraceTests.swift` (new): firing at each of the seven thresholds,
  boundary behavior one day early, plain-number titles with no tier
  names or exclamation marks, and passing 150 without a binding feature
  present (holds at the last milestone, doesn't crash or invent one).
- `CandleDaysLitStateTests.swift` (new): visual-state selection at
  every boundary (6→7, 29→30, 74→75), monotonic height/pool/flame
  progression, and holding at the richest state well past 150 rather
  than resetting (binding isn't built).

## [Unreleased] — build 17 (paywall redesign)

Full visual rebuild of the paywall ("The Ascent"), one screen, no
scrolling down to iPhone SE.

### Added
- `PaywallCandleLogo`: small animated candle in the paywall header,
  replacing the generic mountain icon. Reuses `FlameShape` from
  `CandleView.swift` at a slower, calmer ~2.6s flicker loop (CandleView's
  own loop is deliberately more energetic and too busy for a header
  mark). Only the flame animates — the mark itself never bounces or
  scales. Respects Reduce Motion (static flame when it's on).
- `AscentPalette`: local, light-only warm-paper palette scoped to the
  paywall screen only (`FFFCF6` background, not stark white) — the rest
  of the app stays dark by design via `Theme.swift`.
- Adaptive `isCompact` layout via `GeometryReader` — the "Also included"
  line is the one thing that gets cut on a screen too short to fit
  everything; the CTA and footer never do. Empirically, iPhone SE (the
  smallest supported size) fits everything with room to spare, so the
  cut threshold is set as a safety net below any real supported device
  rather than something SE itself should trigger.

### Fixed
- Duplicate price display: each plan row previously showed its price
  twice (once in the subtitle, once on the right). Now shown exactly
  once, right-aligned — Yearly shows its per-month equivalence, Monthly
  its plain monthly price. Trial/context text moved to the left subtitle
  only, sourced from RevenueCat's real offer text, never hardcoded.
- CTA label now correctly reflects trial eligibility, not just plan
  selection — a lapsed subscriber (not intro-offer-eligible) sees plain
  "Continue" even on Yearly, instead of falsely promising a trial they
  can't get.
- `VergProducts.storekit` had two stale bugs surfaced while testing this
  redesign: product IDs were lowercase (`verg_monthly`/`verg_yearly`)
  while `ProductIdentifiers.swift` expects exact-case `Verg_Monthly`/
  `Verg_Yearly`, so local StoreKit testing could never resolve the
  products; and pricing/trial were still the old $4.99/$60/1-month-trial
  numbers. Both corrected to $7.99/mo, $59.99/yr, 3-day trial on Yearly
  only.

### Changed
- Close button: tap target widened to the full 44×44pt HIG minimum
  (visible glyph stays the same small size), still top-right.
- Footer collapsed to a single line: Restore Purchases · Terms · Privacy.
- Corners standardized to 12pt continuous throughout this screen
  (previously 16pt circular via `Theme.CornerRadius.medium`).
- No purple, no cool gray, no glowing borders anywhere on this screen —
  audited and confirmed against `Theme.Colors.accent` and shadow usage.

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
