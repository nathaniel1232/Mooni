# Onboarding Redesign — Plan

> Goal: turn the current ~25-screen onboarding into a focused, story-paced flow that earns belief, asks for commitment, and converts. One job per screen. No stacked content. Clean background. Story breaks between every question block.

This is the working document we will execute against. Each **Phase** below is independently shippable — we land them in order, top to bottom.

---

## North star (one paragraph)

A user opens the app, gets a single clear value prop, answers 3 light questions, sees their future life on a timeline, answers 10 deeper questions, sees a tracking comparison that shames manual journals, hits a 90%-success-rate visual, sets goals, gets shown an in-app "Allow notifications" mock that *then* triggers the real iOS prompt, leaves a rating with no skip option, signs in, commits, watches a 20-second personalized plan compute, sees their custom numbers (hours, bedtime, wake, deep sleep target), gets a 3-screen auto-tracking pitch that buries manual tracking, signs a digital commitment pledge, and hits paywall already sold.

---

## Phase 0 — Background calm

The current background stacks 80 twinkling stars + drifting bloom on every screen. Per user: too noisy.

**Change `StarsBackground` usage in onboarding only:**
- `count: 80` → `count: 28`
- Add a new `ShootingStarsOverlay` that fires one streak every 12–18 seconds at a random angle (top-right → bottom-left, ~0.9s arc, slight tail). Single `TimelineView` + `Canvas`, no per-star animations.

**Files**
- `Views/Onboarding/OnboardingView.swift` — change count, layer `ShootingStarsOverlay()` next to it.
- `Views/Components/ShootingStarsOverlay.swift` (NEW)

Cost: ~80 LOC, zero risk.

---

## Phase 1 — Step enum rewrite + skips

The current `Step` enum has ~80 cases with ~60 skipped — heavy to read, easy to misorder. Rewrite to **only the steps that will exist** in the new flow. Drop the skip mechanism entirely except for a tiny number of conditional questions.

**Target sequence (~30 screens):**

| # | Step | Type | Notes |
|---|---|---|---|
| 1 | `welcome` | hook | Single value prop, one CTA |
| 2 | `ageQuestion` | warmup Q | Reuse |
| 3 | `genderQuestion` | warmup Q | Reuse — un-skip |
| 4 | `typicalSleepHours` | warmup Q | Reuse |
| 5 | **`lifeTimeline`** | story 1 | NEW — animated 2/4/8-week timeline |
| 5.5 | **`namePet`** | pet | REWRITE UI — clean, minimal, not focal |
| 6 | `wakeFeeling` | identity Q | Reuse |
| 7 | `energyDip` | identity Q | Reuse |
| 8 | `napsDay` | identity Q | Reuse |
| 9 | `racingThoughts` | identity Q | Reuse |
| 10 | `phoneBeforeBed` | identity Q | Reuse |
| 11 | `caffeineCutoff` | identity Q | Reuse |
| 12 | `stressLevel` | identity Q | Reuse |
| 13 | `struggleDuration` | identity Q | Reuse |
| 14 | `biggestProblem` | identity Q | Reuse |
| 15 | `roomEnvironment` | identity Q | Reuse |
| 16 | `schedule` | schedule Q | Reuse — bed + wake time |
| 17 | **`trackingCompare`** | story 2 | NEW — scribbled journal vs Mooni hypnogram |
| 18 | **`targetReachable`** | story 3 | NEW — "90% of users hit this" animation |
| 19 | `personalizeGoals` | goals Q | Reuse |
| 20 | `personalizeBlockers` | goals Q | Reuse |
| 21 | `personalizeImpact` | goals Q | Reuse |
| 22 | `personalizeTried` | goals Q | Reuse — un-skip |
| 23 | `personalizeWindDown` | goals Q | Reuse — un-skip |
| 24 | **`progressBucket`** | story 4 | NEW — bucket fills: manual vs Mooni |
| 25 | `sleepGoal` | commit Q | Reuse — hours target |
| 26 | **`notifAllowMock`** | trick UI | NEW — fake iOS dialog → real prompt |
| 27 | **`ratingPledge`** | rating | REWORK `rateApp` — no skip |
| 28 | `signIn` | commit | Reuse |
| 29 | **`commitReady`** | story 5 | NEW — "you're ready" emotional beat |
| 30 | **`planComputing`** | loading | REWORK `analyzingAnswers` — 20s, sub-bars |
| 31 | **`planReveal`** | payoff | NEW — your numbers (target hrs, bed, wake, deep) |
| 32 | **`autoTrackStoneAge`** | pitch 1 | NEW — manual journals are dead |
| 33 | **`autoTrackHow`** | pitch 2 | NEW — phone signals + Apple Health |
| 34 | **`autoTrackAccuracy`** | pitch 3 | NEW — accuracy bars vs labs |
| 35 | **`signaturePledge`** | ceremony | NEW — draw signature + thumb hold |
| 36 | `prePaywall` | terminal | Reuse — opens paywall sheet |

**To delete from `Step` enum** (and from `content`, `primaryTitle`, `canAdvance`, `shouldSkip`):
- All emotional priming except `welcome`: `hero`, `sleepImpactStat`, `identityDamage`, `emotionalDiscomfort`, `hopeTransformation`
- All benefit screens: `benefitEnergy`, `benefitFocus`, `benefitBody`, `benefitMood`, `benefitLooks`, `benefitLongevity`
- Pet ceremony: `petAttachment`, `namePet`, `bondMessage`, `demo` *(see Open Question 1)*
- Bio fluff: `heightQuestion`, `weightQuestion`
- Fact-chart lectures: `bodyFact`, `sleepDebtFact`, `phoneFact`, `caffeineFact`, `stressFact`, `dayCycleFact`, `environmentFact`
- Auto-track marketing: `autoTrackIntro`, `autoTrackRem`, `autoTrackAccuracy` *(old set — replaced by new 3-screen pitch)*
- Expert quotes: `expertSleepTimes`, `expertGoalFocus`, `expertWakeInertia`
- Padding: `motivationQuestion`, `pseudoAnalysis`, `phoneScreenTime`
- Goal studies: `goalStudy1...5`
- Schedule fluff: `reflection`, `roomPicker`, `anticipation`, `personalize`, `personalizingReveal`
- Permissions: `healthPerm` (deferred to in-app)
- Old reveal/pitch chain: `sleepScoreReveal`, `topIssues`, `bodyStudies`, `scienceCredibility`, `scienceTrust`, `scienceEfficiency`, `scienceArchitecture`, `scienceOnDevice`, `scienceProPromise`
- Filler: `socialProof`, `rateApp` (old), `simulatedResult`, `firstQuest`, `soundsDemo`, `soundscapePreview`, `featureTour`
- Outcome reel: `outcomeImagine`, `outcomeMornings`, `outcomeDays`, `outcomeFuture`

**Conditional skips kept:**
- Skip `caffeineCutoff` if user picks "I don't drink caffeine" on a deeper question — *we can decide this later, not blocking.*

**Files**
- `Views/Onboarding/OnboardingView.swift` — rewrite `Step` enum, `content` switch, `primaryTitle`, `canAdvance`, `shouldSkip` (now near-empty).

Cost: ~300 LOC churn (mostly deletion). Risk: medium — easy to break advance/back navigation.

---

## Phase 2 — Welcome screen rewrite

Current `WelcomeScreen` is fine structurally but the copy is pet-led. Rewrite copy to a sleep-led value prop:

> **Sleep like it matters.**
> Stop guessing your nights. Build a sleep rhythm that runs your mornings, not the other way around.
>
> [ Get Started ]
> Already have an account?

One single emoji/icon, no list of "what's inside", no carousel.

**Files**: `Views/Onboarding/OnboardingView.swift` (WelcomeScreen struct)

---

## Phase 3 — Story moments (4 NEW screens)

Each is a single visual + one line of copy + Continue button. No stacked cards.

### 3a. `lifeTimeline` — life turnaround timeline
A horizontal timeline with 3 markers: **Day 1**, **Week 2**, **Week 8**. Each marker animates in, with one short phrase under it ("Wake without snoozing" → "Energy holds till evening" → "You forget what tired felt like"). Connected by a glowing accent line that draws in left-to-right.

### 3b. `trackingCompare` — manual vs Mooni
Left card: a scribbled paper sleep log (handwritten font, smudge, "?", crossed-out times). Right card: a clean Mooni hypnogram with REM/Deep/Light bars filling in over 1.5s. Title above: *"How you tracked before."* / *"How you track now."* No CTA copy, just Continue.

### 3c. `targetReachable` — 90% reach this
A bar chart with 10 stacked figures, 9 fill green over 1.2s, 1 stays grey. Big number: **90%** of new users hit their first 7-day target. Tap-through.

### 3d. `progressBucket` — bucket filling
Two side-by-side buckets. **Manual** fills slowly with grey droplets, never reaches the top. **Mooni** fills cleanly with accent droplets, hits the top, glows. Continue.

**Files**: each new screen as a `private struct` in a new file: `Views/Onboarding/OnboardingStoryScreens.swift`

Cost: ~600 LOC across the 4 screens.

---

## Phase 4 — In-app notification mock (`notifAllowMock`)

Two stages on one screen:

**Stage A (showing):**
- Faux iOS system dialog at top of screen ("SleepOwl Would Like to Send You Notifications") with Allow/Don't Allow buttons.
- An animated index-finger emoji 👆 hovers over the **Allow** button, gently bobbing.
- Below: *"Tap Allow so your wind-down knows when to begin."*

**Stage B (user taps Allow):**
- Faux dialog dismisses with a satisfying pop.
- Trigger the real `UNUserNotificationCenter.requestAuthorization` immediately.
- After the user responds to the real prompt, advance.

If permission is already determined (denied), we route to Settings as we already do — but in this flow that's a rare edge case.

**Files**: new screen in `OnboardingStoryScreens.swift`; replaces the old `notificationPerm` screen.

---

## Phase 5 — Rating ceremony rewrite (`ratingPledge`)

Per user:
- **No skip button.**
- Big "Leave a rating" CTA.
- On tap → nothing visible for 4–5s while we call `SKStoreReviewController.requestReview` (it can lag).
- After the iOS rating sheet appears and dismisses (or after ~6s if it never shows), reveal a small underlined "**I rated it**" link beneath the button.
- That link is the only path forward.

**Files**: rewrite the existing `RateAppScreen` (already mostly there) — remove skip path, lock the gate behind the link.

---

## Phase 6 — Commit ready (`commitReady`)

A single emotional beat between sign-in and the loading screen:

> **You showed up.**
> That's the hardest part. From here we do the work — together.
> [ I'm in ]

Centered. One emoji 🌙 or pet silhouette. Subtle glow ring. No other UI.

**Files**: new screen in `OnboardingStoryScreens.swift`.

---

## Phase 7 — 20-second plan computing (`planComputing`)

Rework the existing `AnalyzingAnswersScreen` into a layered loading:

- **Big top-center circular progress ring**, 20s to fill.
- Below it, **4 thin horizontal sub-progress bars**, each labelled (e.g. *"Mapping chronotype"*, *"Reading your phone rhythm"*, *"Calibrating wind-down"*, *"Sealing the plan"*) that fill in cascade — each one fills, then the next starts.
- Each sub-bar finishing fires a tiny tick haptic.
- Status text under the ring cycles 6 messages over the 20s.

Variable pacing (existing `runScript` already does this — just retune the script to ~20s total and add the sub-bar visual).

**Files**: rework `AnalyzingAnswersScreen` view + `analyzingScript` timings in `OnboardingView.swift`.

---

## Phase 8 — Plan reveal (`planReveal`)

A single screen, four numbers, each on its own card stamped in with a quick spring + haptic, top to bottom:

1. **Sleep need:** *7.8 hrs/night* (computed from age + survey)
2. **Ideal bedtime:** *10:42 PM* (computed from wake time - sleep need - 20 min onset buffer)
3. **Ideal wake:** *6:30 AM* (user's input, rounded)
4. **Deep sleep target:** *1h 28m* (~18% of sleep need)

Title: *"Your plan is ready, {petName}."*
CTA: *"This is the plan."*

**Files**: new `PlanRevealScreen` in `OnboardingStoryScreens.swift`. Helper computes numbers from `OnboardingProfile` + bedtime/wakeTime state.

---

## Phase 9 — Auto-tracking pitch (3 screens)

### 9a. `autoTrackStoneAge`
A big greyscale image of a paper journal with a pen, crossed out with a red diagonal line. Title: *"Manual sleep tracking is over."* Body: *"You won't remember to log every night. We don't ask you to."*

### 9b. `autoTrackHow`
A diagram: phone icon + Apple Health icon + watch icon (greyed if user doesn't have one) all converging arrows into a Mooni glyph. Bullet rows below: *"Phone activity 8pm–4am"*, *"Apple Health sleep records"*, *"Sanity filters"*. Each row springs in.

### 9c. `autoTrackAccuracy`
A horizontal bar comparison:
- **Mooni vs. polysomnography:** 92% agreement on duration / 86% on stages
- **Manual journals vs. polysomnography:** 41% / 12%
Source line in small text: *"Based on internal validation runs against PSG benchmark."* (need to confirm this is honest — see Open Question 2.)

**Files**: new file `OnboardingAutoTrackScreens.swift` (3 structs).

---

## Phase 10 — Signature pledge (`signaturePledge`)

The commitment ceremony:

- Top: title *"Make it official."*
- Middle: a wide signature pad (CoreGraphics `Path` drawing in a `DragGesture` capture). Faint dotted line. Faint placeholder "sign here".
- Below the pad: a **press-and-hold button** ("Hold to commit"). The button only enables once the user has drawn *something* (≥30 path points). Holding it for 1.8s fills a ring around the thumb icon and advances.

The signature isn't stored anywhere — purely psychological commitment.

**Files**: new file `Views/Onboarding/SignaturePledgeScreen.swift` (plus reusable `HoldToCommitButton` component if helpful).

---

## Phase 11 — Polish

Once everything else is in:
- Tighten transitions (current `.opacity + move` is fine; double-check no janky bounces between new and old screens).
- Audit copy line by line — every word earns its keep.
- Tune the ~25pt content offset from last round across the new screens.
- Check the paywall handoff: the user should land on the real paywall feeling sold, not surprised.

---

## Locked decisions (from user)

1. **Pet presence.** Keep `namePet` near start-to-mid of the flow (just after the warmup Qs and life-timeline beat, before the 10 identity Qs). Not a focal point. **UI rebuilt from scratch — current pet UI is ugly.**
   - New position in the sequence: `welcome → age → gender → typicalSleepHours → lifeTimeline → namePet → wakeFeeling → ...`

2. **Accuracy claims.** No PSG percentages. Copy stays simple and honest: *"We track your sleep automatically from your phone alone. No watch. No wearable. No nightly logging. Just your phone."* The 3-screen pitch becomes:
   - 9a. *"Sleep logs are dead."*
   - 9b. *"Your phone does the work."* (icon diagram, no Apple Watch needed)
   - 9c. *"Set it, forget it."* (one line: fully automated, runs nightly)

3. **Apple Health.** **Not used in onboarding.** Remove all Health permission UI from the flow. (Existing in-app `healthPerm` step removed; Apple Health diagram in Phase 9b also removed — phone-only.)

4. **Global visual refresh** *(applies to entire onboarding, not just new screens)*:
   - **Top chrome**: linear white progress bar across the top, thin (~3pt). Simple back chevron on the left. Drop the circular progress indicator.
   - **Primary CTA buttons**: white background, black text, more rounded (capsule with bigger corner radius). Replaces the current accent-fill style.
   - **Screens**: text-led, primarily white text on the dark background. Drop the purple/accent overuse — accent reserved for charts, animations, progress bars, and rare highlight moments.
   - **Background**: dark stays (purpleish night gradient is fine — that's the "background being purpleish" the user allowed).
   - **Cards / option pills**: white-with-low-opacity fills, white strokes, no purple tint by default. Use accent only when an item is *selected* or for tiny in-card emphasis.
   - Rule of thumb: if it doesn't move (chart, animation, progress fill), it should be white or neutral.

---

## Suggested execution order

We do Phase 0 first (instant win, easy to verify). Then Phase 1 because it gates everything else. Then story screens (Phase 3) so the user can see the flow taking shape. Then permissions/rating/sign-in (Phases 4-5). Then commitment ceremonies (Phases 6-10). Then polish.

| Order | Phase | Estimate | Status |
|---|---|---|---|
| 1 | Phase 0 — Background calm | 30 min | ✅ shipped (28 stars + ShootingStarsOverlay) |
| 1.5 | Visual refresh — top bar + white CTA | 30 min | ✅ shipped (linear white progress; `PrimaryButton(variant: .white)`) |
| 2 | Phase 1 — Step enum rewrite | 1–2 hr | ✅ shipped (36-step enum; all 13 new screens stubbed) |
| 3 | Phase 2 — Welcome + NamePet rewrites | 30 min | ✅ shipped (sleep-led copy; calm pet input) |
| 4 | Phase 3 — Story screens (4) | 3–4 hr | placeholder shipped — replace with full animated treatment |
| 5 | Phase 4 — Notification mock | 1 hr | placeholder shipped — refine pointer + iOS dialog fidelity |
| 6 | Phase 5 — Rating rewrite | 45 min | placeholder shipped — confirm the "I rated it" delay UX |
| 7 | Phase 6 — Commit ready | 30 min | placeholder shipped — refine breathing animation |
| 8 | Phase 7 — 20s loading | 1.5 hr | placeholder shipped (ring + 4 sub-bars) — retune script to 20s |
| 9 | Phase 8 — Plan reveal | 1 hr | placeholder shipped (numbers derived from age + wake time) |
| 10 | Phase 9 — Auto-track 3-pack | 2 hr | placeholder shipped (no PSG claims, phone-only message) |
| 11 | Phase 10 — Signature pledge | 2 hr | placeholder shipped (drag-draw + hold-to-commit) |
| 12 | Phase 11 — Polish | 1 hr | pending |

Total: ~14–16 hours of focused work.

---

## How we work this doc

After every phase ships, update its row above with **✅ shipped** + date + commit ref. If something changes mid-build (a screen splits, a step gets renamed), edit this doc *first* so it stays the source of truth for the next session.
