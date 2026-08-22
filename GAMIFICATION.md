# Verg Progression

How progression works in Verg. Originally written toward a Duolingo-style
roadmap (XP, levels, quests, leagues) — that roadmap is retired as of the
Dante/Virgil business-model pass. It actively contradicted the product's
own governing rule: the app should get *less* interesting to look at over
time, not more. No badges, no points, no currency, no push notifications.

## Three progression tracks, one ledger

All three persist through `AchievementService` (`Core/Services/AchievementService.swift`)
with typed, namespaced UserDefaults keys — one service, three independent
unlock sets, none of them touch each other's state.

**1. Page-count milestones** (`Core/Models/Milestone.swift`) — 10, 25, 50,
100, 250, 500, 1000 pages. The original track. Full-screen celebration
(`MilestoneCelebrationView`) after a page saves. Surfaced on the Stats
carousel and `MilestonesView` — that view is a badge grid, which is
honestly a poor fit for the new "no badges" philosophy; it predates this
rule and hasn't been rebuilt yet.

**2. Weekly-goal milestones** (`Core/Models/WeeklyGoalMilestone.swift`) —
1, 4, 12, 26, 52 completed weeks meeting the days-per-week pace chosen
during onboarding. Same full-screen celebration treatment as page
milestones (reuses `MilestoneCelebrationView` via a second initializer).
Only relevant if the user set a commitment; nothing shows otherwise.

**3. Seven Terraces** (`Core/Models/Terrace.swift`) — 7, 14, 30, 60, 100,
200, 365 days lit. The one built *with* the no-badges rule in mind: no
full-screen takeover, just a small auto-dismissing line of text after the
bell (see `TimerView`'s terrace banner). This is the intended template
for future progression surfaces, not tracks 1 and 2.

**Backfill rule** (all three): on first run after a track is introduced,
already-earned thresholds are seeded silently — no retroactive
celebrations for existing progress.

## Business model note (supersedes the old "keep it free" note)

Per the 2026-08-22 freemium pass: page-count milestones, weekly-goal
milestones, and general Stats are Ascent (paid) — only "days lit" and the
calendar are free, alongside the ritual itself. Terraces are checked
regardless of subscription tier (the quiet banner isn't gated), but the
Stats surfaces that show milestone *progress* are behind the paywall like
the rest of Stats.

## Retired roadmap (do not build)

The following were previously planned and are now explicitly out of scope
per the product's own rules — raise it with the user again before
reviving any of it:

- XP, levels, level badges
- Daily quests
- Leaderboards / leagues / any social or account-backed system
- Any purchasable/consumable version of a "streak freeze" (relights are
  subscription-included only, never sold separately — see `CandleRelight.swift`)

## Open follow-up

`MilestonesView`'s badge grid (track 1) and the full-screen celebration
used by tracks 1 and 2 predate the "no badges, quiet" rule that shaped
track 3. Worth revisiting whether all three should converge on the
Terrace treatment, or whether page-count/weekly-goal are different enough
in kind to keep their current presentation. Flagged, not decided.
