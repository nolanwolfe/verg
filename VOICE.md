# Verg — Character & Voice Guide

The single source of truth for how Verg speaks. Every user-visible string
should be checkable against this document. When a new string is proposed,
ask: *would the character say this, this way?* If not, rewrite it.

---

## 1. The Character: the guide on the ascent

Verg is named for Virgil — the poet who walks Dante through the Inferno and
up the mountain of Purgatory. The app's character **is** that guide:

- **Calm, present, unhurried.** A guide who has made the climb before and
  isn't anxious about your pace. Never hype, never cheerleading.
- **Speaks in short, declarative sentences.** Statements, not exclamations.
  "Light your candle." "Seven days lit." Full stops, not fireworks.
- **Warm, not soft.** The guide respects you enough not to coddle. Failure
  is stated plainly and without judgment: "The candle went out. Light it
  again." — not "Oops! You broke your streak 😢"
- **Never moralizes.** No lessons, no "remember: consistency is key." The
  ritual speaks for itself. The projection screen shows the honest math and
  lets the user draw the conclusion.
- **Points, doesn't push.** Buttons and invitations are invitations:
  "Begin Writing", "Start your first session." Never "Don't miss out!",
  never urgency, never guilt.
- **Quiet about itself.** The guide is not the protagonist — the user is.
  Milestones are marked with one line of text, not a celebration of the app.

### Who the character is NOT

- Not a therapist, coach, or guru. No "you've got this!", no affirmations,
  no psychological framing ("How does that make you feel?").
- Not a gamified mascot. No XP-speak ("level up!", "quest complete"), no
  confetti energy, no emoji in app copy.
- Not corporate. No "We value your journey", no marketing adjectives
  ("amazing", "incredible", "seamless").
- Not chatty. Verg never asks how the user's day went. The paper does that.

### The one relationship rule

The app addresses **one person, directly, in second person** ("your
candle", "you wrote for N minutes"). Never "users", never "we hope you…".
The guide speaks *to* the writer, not *about* them.

---

## 2. Voice principles (checklist for any string)

1. **No exclamation marks.** The single exception in the entire app is the
   Settings share-sheet text, which addresses a third party, not the user.
   Do not add a second exception.
2. **No direct questions**, except the three deliberate destructive
   confirmations ("Delete this page?", "Delete this book?", "Finish this
   journal?"). Questions elsewhere put the app in the interrogative,
   subservient position; statements keep the guide's footing.
3. **No emoji.** Anywhere. The candle is the only symbol.
4. **No streak language.** It is always "days lit"; a miss is "the candle
   went out", never "streak broken". A relight is a relight — it never
   pretends a day was written.
5. **Plain numbers.** Milestones say "Seven days lit." — spelled-out small
   numbers in prose, numerals in stats ("117 pages"). No "🎉 7-DAY
   MILESTONE!" framing.
6. **Short beats long.** If a string can lose a word, it loses the word.
   One-line strings are the ideal; two clauses is the ceiling for most UI.
7. **Concrete over abstract.** "Write on paper while the candle burns" —
   not "engage in mindful journaling practice."
8. **Honesty over motivation.** The onboarding projection shows the real
   number of pages/hours at the chosen pace, unflattering or not. Never
   inflate, never flatter.
9. **Quiet celebration.** Big moments get *less* ornament, not more: a big
   number, a spring, a haptic, one line of text. Terraces are "a marked day
   and one line of text."
10. **Serif only once.** The Dante/Virgil epigraph is the only serif screen
    in the app. Voice and type agree: that moment is set apart; everything
    else is the same calm register.

---

## 3. Register by surface

| Surface | Register | Example |
|---|---|---|
| Onboarding | Ceremonial but brief; the epigraph sets the frame, steps are imperative and plain | "Light a candle. Write until it burns out." |
| Home | Minimal, present-tense, states the ritual | "Light your candle." / "3 days lit" |
| Timer / session | Nearly silent. The candle does the talking | "Writing..." |
| Milestones | One declarative line, fades on its own | "Seven days lit." |
| Time Reclaimed reveal | One honest sentence with the number | "You wrote for 12 minutes instead of scrolling" |
| Paywall | The same voice, applied to the offer — no sales pressure, no countdown timers, no "BEST VALUE" | "On the Verg of Becoming" |
| Errors / destructive confirms | Plain, factual; questions allowed only here | "Delete this page?" |
| App Store copy | The voice, one notch more outward-facing — still declarative, still no exclamation marks | "Your journal, leveled up." → prefer "Your journal, continued." (see §5) |
| Notifications | One calm sentence, no urgency | "Take 10 minutes to write." |

---

## 4. Vocabulary

**Use:** candle, light / lit, flame, burn, bell, page, paper, book, shelf,
ascent, terrace, pace, ritual, session, relight, archive, reclaimed.

**Avoid:** streak, badge, points, XP, level, quest, reward (as gamified
noun), unlock (except literal paywall gating — prefer "included with The
Ascent"), journey (overused by competitors; the ascent is ours), wellness /
mindfulness (category language, not ours), hack, boost, supercharge,
"mental health companion".

**Competitor contrast:** stoic. is a mental-health companion — soft, guided,
feature-rich. Verg is a **ritual** — a candle, paper, a bell, and your own
handwriting. Where they guide your feelings, Verg protects your attention
("Time Reclaimed" — minutes written instead of scrolled). Voice should never
drift toward therapy-speak; that's their lane.

---

## 5. Copy patterns (steal these shapes)

- **State, then invite.** "The candle went out. Light it again."
- **Number + noun, full stop.** "Seven days lit." "117 pages."
- **The honest trade.** "You wrote for N minutes instead of scrolling."
- **The plain imperative.** "Set your phone down." "Pick a number you can keep."
- **The quiet offer.** "Relight the candle with The Ascent." (never "Upgrade
  NOW to save your streak!!")

### Headline decision (resolved)

The 2.2 App Store headline was "Your journal, leveled up" — gamified language
the retired roadmap banned and this guide rules out. Resolved in the 2.2 copy
pass: the headline is now **"Light a candle. Write until it burns out."**
(the onboarding line itself). RELEASE_NOTES_2.2.md updated to match.

---

## 6. Enforcement

- All user-visible strings live in `Core/Constants/AppStrings.swift`. New
  copy goes there, not inline in views.
- Before submission, grep the string file and views for: `!`, `?` (outside
  the three sanctioned confirmations), emoji, "streak", "badge", "level",
  "journey", "amazing", "we're excited".
- The existing test asserting coach-mark copy
  (`SessionGatingServiceTests`) is the pattern: pin voice-critical strings
  in tests so drift fails CI.
