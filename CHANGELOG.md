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

### Fixed — journal swiping, close-up capture, and a background-thread write

**Swiping between journal pages.** The fullscreen viewer layers a
swipe-down-to-dismiss recogniser over the pager's own horizontal gesture,
and it was configured to recognise simultaneously with *everything*. So a
sideways swipe between entries also ran the dismiss handler: any downward
drift in the swipe slid the photo around inside its page and faded the
chrome out mid-transition. The dismiss pan now only begins on a
predominantly-downward drag, and only shares touches with its own scroll
view's recognisers.

- A `.cancelled` gesture no longer counts as a dismissal. It shared a branch
  with `.ended`, so a drag the system took away could close the viewer on the
  user's behalf.
- Pages no longer downgrade a decoded full-resolution image back to a
  thumbnail when they leave the sharp window — swiping back and forth
  visibly dropped each page to blurry, then popped it sharp again.
- The full-image cache ceiling (64 MB / 8 objects) sat exactly on top of the
  viewer's own ±2 page window, so every swipe evicted a page that was about
  to be needed. Raised to 112 MB / 12.

**Close-up photos of a page.** The camera asked for
`.builtInWideAngleCamera` directly. That lens cannot focus nearer than about
10 cm — closer than that and the page fills the frame but never comes sharp,
which is exactly the shot this app exists to take. iOS reaches macro by
switching to the *ultra-wide* lens, and only offers that when the session is
given a virtual multi-camera device. Now prefers triple → dual-wide → dual →
wide, and opts in to automatic lens switching.

- Opens on the wide lens. On a virtual device zoom factor 1.0 selects the
  ultra-wide, so the default would have been a distorted, far-too-wide frame
  labelled "1x".
- Added a 0.5x/1x/2x selector (shown only when the device has a real choice)
  and a torch toggle, since this is an app about writing in a dim room.
- Session configuration moved off the main thread, and both early-return
  paths now balance `beginConfiguration()` — they returned without
  committing, leaving the session wedged mid-configuration.
- The torch is extinguished when the camera closes.

**Other**

- Saving a page mutated `@Published` state from a background queue,
  publishing into SwiftUI off-main. The encode and disk write stay
  backgrounded; the state change is now on the main actor.
- Tapping a locked page in the Journal tab did nothing at all: it set the
  date the paywall would explain but never presented it.


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

### Changed — paywall fits one screen; onboarding closing screen
- The paywall is now two regions: a scrolling upper half (header, features,
  reviews, laurel) and a **fixed block from Yearly down** — plans, button,
  assurance and links never move. Spacing and the laurel were tightened
  until the whole thing fits without scrolling on a normal iPhone; on an SE
  the upper half scrolls behind a soft bottom fade, and the second review
  is what falls below the line.
- Feature row 3 ends "year-by-year facts."
- Onboarding's closing screen: the title dropped from `largeTitle` to
  `title` — at 34pt it wrapped to two lines and pushed the screen past the
  bottom on an SE — and "It helps others find Verg 🕯️" is back on one line.

### Changed — paywall close affordance, pricing display, copy
- Feature row 2: "Real paper progress of who you're becoming, and insights
  to prove it."
- The close X is **hidden until its corner is touched**. The 44x44 target is
  always live: first tap reveals the glyph, second dismisses, and it fades
  back out after three seconds so the screen stays uninterrupted.
- Yearly's "/mo" figure now **floors to the cent instead of rounding**:
  $59.99 ÷ 12 is $4.9992, which was rendering as $5.00. That both overstated
  the price and undercut the comparison against $7.99 monthly. Flooring can
  never claim the plan is cheaper than it actually is.
- Settings' "How to write with Verg" carries the Verg candle rather than a
  book glyph — `SettingsButtonRow` gained an opt-in `usesCandleMark`.

### Changed — the Oracle, interface feedback, Settings groups of three
- Prompts are now **the Oracle**, and a prompt is a **script**. The sheet
  draws one at a time ("Draw another"), holds your own under "Your
  scripts", and "No script" is still an explicit choice.
- The 20 built-in prompts replaced with **24 written to be thought-provoking
  but plain** — "Name the thing you keep almost doing.", "What you are
  protecting by staying busy.", "What silence usually interrupts." Still
  under the 60-character ceiling the tests enforce.
- Write screen pills no longer change colour at all; state is carried by
  the label or the icon, so the candle stays the only lit thing there.
  The Oracle pill reads "No script" / "Script set"; the Sound pill keeps
  the speaker icon and crosses it out when off.
- **Sound and haptics across the interface.** `AudioService.playUITick()`
  fires on tab switches, Settings rows and every toggle. The haptic is
  always there; the sound follows the Sound setting, so that one switch
  governs the whole interface rather than just the bells. AudioService now
  also reads that setting at launch — it previously assumed sound was on
  until Settings was opened.
- **Settings in groups of three.** Candle (duration, sound, ambience),
  Guide (how to write with Verg, the Oracle, history style), Notifications,
  Account. The Golden Age is one row that reports On/Off rather than
  appearing and disappearing with subscription state, which keeps Account
  at a stable three.
- Tab bar glass strengthened: the black tint dropped 0.72 → 0.55 so the
  material actually shows through, the specular highlight brightened, a
  counter-light added along the bottom edge, and the rim doubled in
  contrast. At the old values the blur was entirely swallowed and the pill
  read as flat.

### Changed — Settings regrouped, pill labels, paywall spacing
- Settings' Timer, Prompts and Archive sections merged into one **Candle**
  group: Duration, Sound, Ambience, Prompts, Calendar Style. They were
  three sections all describing the same thing — how a session is set up
  and recorded.
- The Golden Age row's icon is `laurel.leading`, the closest thing SF
  Symbols has to a single wheat stalk, echoing the paywall's laurel.
- Write screen: the Music pill is always the plain music note. The
  crossed-out speaker read as an error state rather than an off state —
  on/off is carried by the border, same as the other two pills.
- The Prompt pill now reads **"No prompt"** when none is set and "Prompt"
  when one is, so the row states which of the two it's in. Still two fixed
  labels rather than the prompt text, which would change the pill's width
  on every shuffle.
- Paywall spacing opened back up — section gaps 12→24pt, feature rows and
  review cards given their padding back. It no longer forces itself onto
  one screen; the upper half scrolls to be read, and the plans, button and
  links stay fixed, so nothing needed for buying is ever out of reach.

### Changed — onboarding closing screen mark
- Five gold stars replace the flickering candle, reusing the achievements'
  `AchievementStarIcon` so it's literally the same star an earned row
  carries. The component gained `size` and `phase` parameters; the five are
  staggered by 0.12s each, since starting them together made the row blink
  in lockstep rather than glimmer.

### Fixed — candle jump on pause (again)
- `TimerView` was back to `isBurning: viewModel.isRunning`; the earlier fix
  was lost when files were being edited from two places at once. Restored
  to `!viewModel.isComplete`. CandleView drops its glow and flame out of
  the layout when not burning, shrinking its rendered height by ~210pt —
  and since the candle is centred with `.position()`, that made the whole
  thing jump on pause. Pausing isn't blowing the candle out.

### Fixed — page viewer flashing while swiping a book
- The fullscreen viewer swapped each page between `FullScreenPageView` and
  a plain `Color.black` as the ±2 window slid. That changes the page's view
  identity on every swipe, so SwiftUI tore the page down and rebuilt it —
  discarding the already-decoded image held in its `@State` and flashing a
  placeholder mid-swipe.
- The window is now a parameter (`isWindowed`) rather than a branch, so
  identity is stable and only the content changes. Memory is still bounded:
  a page outside the window releases its image explicitly.

### Added — prompts on the page, and a third pill
- The chosen prompt is now saved with the page (`Session.prompt`, tolerant
  decode so older pages simply have none) and shown in the fullscreen
  viewer's metadata beneath the date and duration.
- **No prompt** is a real choice, not just an absence: a button in the
  prompt sheet, and the sheet no longer auto-shuffles on open — it used to
  silently undo that choice every time it was reopened.
- The Prompt pill always reads "Prompt". Showing the chosen prompt in it
  made the pill change width on every shuffle, shoving the whole row
  around. Its border brightens instead when a prompt is set.
- **Music** pill added beside it, toggling ambience directly (paywalled
  like the Settings row). All three pills now share one shape and split the
  row evenly.
- Settings gains a **Prompts** section opening the same library.

### Added — writing prompts
- A **Prompt** pill on the Write screen, beside the timer pill and built
  from the same capsule, border and type. It shows the current prompt
  truncated to one line — the pill is the reminder, the sheet is where a
  prompt is actually read.
- Tapping opens a sheet with the prompt set large and two buttons:
  **New prompt** shuffles, **Your prompts** opens the collection.
- 20 built-in prompts (`WritingPrompt.builtInTexts`), deliberately short —
  a prompt is a door, not a paragraph. No questions the app answers for
  you, no therapy framing. Pinned by tests: every built-in stays under 60
  characters and carries no exclamation mark.
- **Your own prompts, in folders.** Add, edit, delete, and move prompts
  between folders (or leave them loose). Deleting a folder keeps its
  prompts rather than destroying them — the button says so.
- Persisted in UserDefaults alongside sessions and books
  (`verg.customPrompts`, `verg.promptFolders`). Built-ins are never
  persisted; they're a fixed set that the shuffle always draws from.
- `WritingPrompt.next(from:after:)` is pure so the shuffle is testable
  without a view: it never repeats the current prompt unless the pool
  holds exactly one.
- New files `Core/Models/WritingPrompt.swift` and
  `Features/Prompts/PromptsView.swift`, registered in project.pbxproj via
  the xcodeproj gem (this project uses manual PBX entries).

### Changed — paywall reviews, laurel placement
- Attributions cut to bare "— Sibylla" and "— Dante". Both read fine as
  usernames, so the disclosure moved to a three-word line directly under
  the review pair: **"Not real reviews."** It renders as part of
  `reviewStack`, so the cards and the line can't be separated by a layout
  change. Do not remove it — without it these are two invented five-star
  testimonials beside a Buy button.
- The laurel moved out from below the fold to sit between the reviews and
  the Yearly row, replacing the scroll chevron. Below the fold now holds
  only the reviews on screens too short for them inline (an SE), so a
  large phone simply doesn't scroll.
- Feature copy trimmed: row 2 is "Insights alongside your entire progress
  on paper of who you're becoming."; row 3 drops "extra" before "candle
  wicks".
- Onboarding's closing screen breaks its body across two lines so the app
  name sits centred on its own: "It helps others find" / "Verg 🕯️".

### Changed — projection closing line, closing-screen mark
- The projection screen now ends on a spelled-out line: "Two hundred sixty
  pages you can hold." Computed, not fixed — 3 days a week is 156 pages
  and 7 is 364, so a hardcoded "two hundred sixty" would be wrong for two
  of the three paces. Lives on `OnboardingProjection.Result.closingLine`.
- Closing screen's mark is `CandleTabIcon` (the whole candle, with the tab
  bar's flicker loop) rather than the static `CandleFlameIcon`, and its
  body line reads "It helps others find Verg 🕯️".
- **Onboarding is purple again.** The ember pass from the previous entry
  is reverted: page dots, pace selection, ritual icons and the shared
  `Theme.Shadows.button` glow are back to `Colors.accent`. Home's button
  glow reverts with it, since it was the same token.

### Changed — paywall structure
- Three feature rows again, the third being customization; the merged
  two-row version was a five-line paragraph on an SE.
- Attributions are prefixed with an em dash — "— Sibylla of Cumae",
  "— Dante, c. 1320". The epithet and the date are back because the
  standalone "not real customers" line is gone: something on the screen
  has to mark these as historical figures rather than usernames, and
  doing it inline is shorter than a disclaimer sentence.
- The scroll chevron moved from beneath the footer to between the reviews
  and the Yearly row, pointing at the laurel that scrolls up from under
  the plans.
- A pinned-bottom variant (plans fixed, everything above scrolling) was
  tried first and reverted: on an SE it left a ~250pt scroll window for
  ~700pt of content, which clipped a review card mid-sentence against the
  Yearly row.

### Changed — onboarding copy and colour
- **Screen 2** is now "A journal without typing." over "Pen, paper, ten
  minutes.", replacing the heavy three-line "Light the candle. Write on
  paper until it burns out." The candle is the hero here and is sized
  close to how it appears on Home, since this doubles as the first look
  at the main screen.
- **Screen 3** labels tightened to the verb: "Light the candle", "Phone
  face down", "Write until the bell", "Photograph the page". Note "until
  the bell", not "until it burns out" — a candle going out is what a
  missed day means, and the metaphor shouldn't carry both.
- **Screen 6** is "One rating lights the way." over "It helps others find
  Verg." The purple heart is gone; the mark is `CandleFlameIcon`.
- Screens 1, 4 and 5 unchanged.
- **Every purple accent on these screens is now ember** (`flameOuter`):
  page dots, the pace options' selected border and checkmark, the ritual
  row icons, and the glow under Continue. On a black screen with a candle
  on it the flame should be the only source of colour.
- The Continue glow lives on the shared `Theme.Shadows.button` token, so
  **Home's "Light Candle & Begin Writing" button warms up too** — same
  reasoning, and that screen has the same candle on the same black.
- Home's primary button reads "Light Candle & Begin Writing" (was "Begin
  Writing"), and `HomeViewModel.buttonText` now reads from
  `AppStrings.Home.beginWriting` instead of hardcoding the string.

### Changed — paywall review attributions
- Cut to bare first names, "Sibylla" and "Dante". That removes the last
  inline signal that they're jokes, which makes the below-fold line
  ("Sibylla and Dante are, regrettably, not real customers.") the only
  disclosure on the screen. It is load-bearing now — noted in
  `AppStrings.Paywall.reviews`. Don't delete or soften it, and don't let
  it end up on a screen the reviews aren't on.

### Changed — the paid tier is "The Golden Age"
- Settled on **The Golden Age** (Virgil's *aurea aetas*), after a shorter
  pass through plain "Golden". Written in full with the article
  everywhere: "with The Golden Age", "Included with The Golden Age".
- Paywall CTA is the name itself — **The Golden Age**, white on a gold
  gradient button. The gradient is deliberately deeper than the app's
  ember tokens (`ctaGradient`, not `flameGradient`); white on the pale
  ember yellow failed contrast outright.
- Paywall copy rewritten: subtitle is now "Put the phone down. Light the
  candle. You owe it to yourself." Three benefit rows (journal, progress,
  the high-end features consolidated into one line), which let the
  separate "Also included" line be deleted.
- The five-star review card moved into the slack between the pitch and
  the plans, so the gap on tall screens holds something. Its content is
  **a joke, and has to stay legibly one**: Dante, dated c. 1320 and
  labelled "not a verified purchaser", in period diction. It also stops
  short of a health claim — "my soul was the better for it" rather than
  anything about mental health, which on a paywall would be a
  therapeutic promise the app can't make. A straight-faced invented
  testimonial here would be a fake review (App Store Guideline 2.3.1,
  FTC 2024 consumer-review rule); a real one pasted from App Store
  Connect is the only other acceptable content for that slot.
- `GoldenPalette` keeps its name — it's the palette of golds, internal to
  the paywall, and renaming it again buys nothing.

### Changed — the paid tier was renamed from "The Ascent"
- Renamed the subscription from **The Ascent** to **Golden**, after the
  golden bough in the *Aeneid* — the token that lets Aeneas return from
  the underworld. "The Ascent" named the climb, which is free; the name
  should sit on what's actually bought, which is the way back to pages
  you already wrote.
- Copy updated everywhere it's user-visible: paywall subtitle, Settings
  account row, locked-stat overlay ("Included with Golden."), locked
  milestones hint, access-code sheet. Written bare — "with Golden", no
  article, no "Verg Golden".
- Paywall CTA is now **"Get Golden"** (was "Begin the Ascent"). "Begin
  Golden" doesn't parse — Golden is an adjective doing proper-noun work,
  so it resists the "Begin X" shape that "Begin Writing" uses. Trial
  suffix behavior unchanged ("Get Golden — 3 days free").
- `AscentPalette` → `GoldenPalette` (internal, paywall-scoped).
- VOICE.md records the name and how to write it; GAMIFICATION.md,
  RELEASE_NOTES_2.2.md, and the sounds README follow. Historical
  changelog entries below keep saying "The Ascent" on purpose — they're
  a record of what shipped then.
- No StoreKit or RevenueCat changes: entitlement identifier and the
  `Verg_Monthly` / `Verg_Yearly` product IDs are untouched. The display
  name in App Store Connect / RevenueCat is a manual follow-up.

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
