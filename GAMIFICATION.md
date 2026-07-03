# Verg Gamification

How progression works in Verg today, and the roadmap for building it out
Duolingo-style. Written alongside the 2.2 milestone release.

## Current model (2.2)

**`Milestone`** (`Core/Models/Milestone.swift`) — the first achievement kind.
Pure Foundation, fully testable standalone:

- Page-count thresholds: 10, 25, 50, 100, 250, 500, 1000
- `nextMilestone(after:)`, `progress(totalSessions:)` — drive the Stats
  carousel's progress card
- `earnedThresholds(totalSessions:)` / `newlyCrossed(totalSessions:unlocked:)` —
  pure unlock logic, no side effects

**`AchievementService`** (`Core/Services/AchievementService.swift`) — the single
unlock ledger:

- Persists unlocked thresholds as JSON `[Int]` under UserDefaults key
  `"verg.achievements"`
- **Backfill rule:** on first run after updating, milestones the user already
  passed are seeded silently — no retroactive celebrations. This matters for
  existing users with 100+ pages.
- `checkForNewMilestones(totalSessions:)` records everything newly crossed and
  returns the highest milestone to celebrate (or nil)

**Celebration hook:** `TimerViewModel.onPhotoSaved()` — after a page is saved,
new milestones trigger `MilestoneCelebrationView` (full-screen overlay in
`TimerView`) before the session completes. The skip-photo path records no
session, so no check is needed there.

**Surfacing:** Stats tab carousel page 4 shows progress toward the next
milestone ("117 / 250 pages") and opens `MilestonesView`, a badge grid of all
milestones (unlocked glow, locked dimmed).

## Design principles

1. **One ledger.** Every future unlockable persists through
   `AchievementService` with typed, namespaced keys (`verg.achievements`,
   later e.g. `verg.xp`, `verg.quests`). No scattered UserDefaults flags.
2. **Pure logic, thin service.** Unlock rules live as pure static functions on
   the model (testable via plain `swift` scripts); the service only owns
   persistence and publishing.
3. **Backfill, never re-celebrate.** Any new achievement kind must seed
   already-earned state silently on first run.
4. **Celebrate at the moment of progress** — right after a page is saved, not
   on app launch.

## Roadmap

**v2.3 — XP + levels**
- XP per completed session, weighted by duration (e.g. 10 XP per 5 minutes,
  capped per day to discourage grinding)
- Level curve mapped to candle imagery (Spark → Flame → Blaze → …)
- XP total on the Stats carousel; level badge next to the streak flame

**v2.3/2.4 — Daily quests**
- Rotating small goals: "write before 9am", "2 sessions today", "add a photo"
- Quest state is date-scoped; completing all daily quests grants bonus XP
- Surfaced as a small card on Home under the streak

**v2.4 — Streak freezes**
- Earnable (via quests/XP) or Pro-included; consumes automatically on a missed
  day. `UserStats.validateStreak()` is the integration point.

**Later — Leagues / friends (requires backend)**
- Weekly XP leaderboards among cohorts, Duolingo-style promotion/demotion
- Needs accounts + server; out of scope for local-only Verg. Revisit once the
  app has an account system for sync.

**Monetization note:** keep achievements/milestones free (they drive retention
and habit), gate comfort/delight features (ambience, freezes beyond the first)
behind Pro.
