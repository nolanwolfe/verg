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
- [ ] Time Reclaimed: after a session, toast reads "You wrote for N minutes
      instead of scrolling" (or the running daily total on a 2nd+ same-day
      session) — dismisses on its own after ~4s, tap also dismisses, never
      reappears until the next session. Background the app mid-session and
      confirm the backgrounded minutes are NOT counted (compare toast/Stats
      total against a stopwatch of foreground time only). Stats tab shows a
      correct This Week total + delta vs. last week + streak, and an
      all-time total in the carousel. Weekly Recap toggle in Settings is off
      by default and, when enabled, requests notification permission

## Version

- Marketing version: 2.2
- Build: 7
