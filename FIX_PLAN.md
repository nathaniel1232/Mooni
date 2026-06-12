# SleepOwl — Fix Plan

Six workstreams, ordered by how I'd execute them. Every item has the root cause,
the exact files, and the fix. Workstream 6 is the "sleep brain" design.

---

## 1. Progress rings — kill the ugly start point (app-wide)

**Root cause:** almost every ring in the app strokes its arc with the same
pattern:

```swift
AngularGradient(colors: [tint.opacity(0.4), tint, .white, tint], center: .center)
```

An `AngularGradient` starts at the 3 o'clock position; the ring is rotated
-90°, so the gradient's first stop (40 % faded tint) lands exactly on the
arc's starting cap at 12 o'clock. That's the "ugly starting point going into
colors": the ring begins washed-out, brightens, hits a white hot-spot ¾ of the
way around, then snaps back to tint. Several rings also stack a blurred halo
circle + a colored shadow on top (the glow).

**Fix:** one consistent treatment everywhere — track `Color.white.opacity(0.08–0.10)`,
progress arc in **solid** tint (or a start/end-matched gradient, never a white
stop), `lineCap: .round`, no halo blur, no colored shadow.

Locations to change:

- [ ] `Mooni/Mooni/Views/Components/SleepScoreRing.swift:27` — in-app score ring
- [ ] `Mooni/Mooni/Views/Onboarding/OnboardingNewFlowScreens.swift:1369` — PlanComputingScreen ring ("ANALYZING %")
- [ ] `OnboardingNewFlowScreens.swift:1419` — PlanComputingScreen sub-bars use `LinearGradient([accent, .white])` → solid accent
- [ ] `OnboardingNewFlowScreens.swift:1605` — PlanRevealScreen heroRing (the "PROJECTED SCORE 87" in the screenshot)
- [ ] `MooniSleepWidget/SmallSleepWidgetView.swift:73`
- [ ] `MooniSleepWidget/MediumSleepWidgetView.swift:56`
- [ ] `MooniSleepWidget/SleepScoreRing.swift:22` + `FriendsSleepWidgetView.swift:83` — audit, same fix
- [ ] Audit remaining `trim(from:` rings in `OnboardingView.swift` (3220, 3383, 4163, 4210, 6818, 8384–8410, 8527), `PrePaywallView.swift:1375`, `SleepReportView.swift` (314, 589, 693, 727), `HomeView.swift:1202` — apply wherever the gradient/white-stop or halo pattern appears.

Consider extracting a tiny shared `MooniRing(progress:tint:lineWidth:)` so this
can never drift again (app target; widget keeps its own copy of the style).

---

## 2. De-glow the "making a plan" screens

These two screens are the only ones with blur-halo glow; user wants them
normal like every other page.

- [ ] **PlanComputingScreen** (`OnboardingNewFlowScreens.swift:1358–1391`):
      remove `Circle().fill(accent.opacity(0.18)).blur(radius: 26)` halo and the
      `.shadow(color: accent.opacity(0.5), radius: 9)` on the arc. Solid ring per §1.
- [ ] **PlanRevealScreen heroRing** (`OnboardingNewFlowScreens.swift:1589–1636`):
      remove halo `blur(radius: 28)` and `.shadow(radius: 12)`; make the score
      number solid white instead of white→tint gradient (the gradient is part of
      the glowy look).
- [ ] **"Building your plan" loader** (`OnboardingView.swift:~4740–4856`):
      remove the radial-gradient blob with `.blur(radius: 22)` behind the pet;
      keep the pet + message + progress strip. The orbital rings can stay if they
      read clean without the glow — otherwise drop to a simple static ring.

Everything else on those screens (cards, schedule strip, copy) already matches
the rest of onboarding and stays.

---

## 3. Widgets — redesign + make the onboarding preview match reality

Two separate bugs:

**(a) The actual widgets look bad.** Current design stacks: tinted halo blur
behind the ring, white-stop angular gradient ring with glow shadow, gradient
score text, two `plusLighter` radial glows on the background, star speckles,
chips with tinted borders. Too much competing for 158 pt.

Redesign (all in `MooniSleepWidget/`):
- [ ] `SleepWidgetBackground.swift` — flatten to the in-app `MooniGradient.night`
      colors, one *subtle* tint wash max, keep (or thin out) the speckles, keep
      the hairline border.
- [ ] `SmallSleepWidgetView.swift` — drop halo blur + ring gradient + score-text
      gradient (solid white number, solid tint ring). Keep brand row / quality
      pill / footer but reduce border noise (one chip, no tinted strokes).
- [ ] `MediumSleepWidgetView.swift` — same ring fix; keep the left-ring/right-stats
      layout, simplify chips.
- [ ] `FriendsSleepWidgetView.swift` — audit for the same patterns.

**(b) The onboarding preview is a hand-built fake.** `WidgetShowcaseScreen`
(`OnboardingNewFlowScreens.swift:2578–2784`) draws its own flat-navy mock with a
sparkline that doesn't exist in the real medium widget.

Fix for permanent parity:
- [ ] Add the widget view files (`SmallSleepWidgetView`, `MediumSleepWidgetView`,
      `SleepWidgetBackground`, `SleepScoreRing`, `SleepWidgetData`) to the **app
      target's** membership too (they're plain SwiftUI, no WidgetKit imports needed
      in the views themselves — verify and split out any `WidgetKit` import).
- [ ] Add a `SleepWidgetData.sample` (87 score / 7h 32m / 11:42 PM → 7:14 AM).
- [ ] `WidgetShowcaseScreen` renders the REAL views inside proper widget frames
      (≈158×158 and ≈338×158, 22 pt continuous corners, real background) and the
      hand-built `smallWidget` / `mediumWidget` mocks get deleted.

---

## 4. Paywall polish (`Mooni/Mooni/Views/Paywall/PaywallView.swift`)

- [ ] **CTA contrast** (`purchaseButton`, :817–825): background is
      `accentSoft → accent` (very light lavender on the left) with white text —
      that's the "can't read the button" complaint. Change to a darker, saturated
      indigo gradient (e.g. `accent → Color(red: 0.45, green: 0.38, blue: 0.95)`)
      or solid `MooniColor.accent`; bump label to heavy weight; reduce the glow
      shadow (`radius: 16 → 8`, lower opacity).
- [ ] **Logo too big** (`heroBlock`, :294–323): icon 104 → 84 pt, halo frame
      230×156 → ~180×120, shadow radius 22 → 12, container height 128 → ~104.
- [ ] **Background bleeding under pinned UI** (:91–96, 188–242): `StarsBackground`
      fills the whole screen and the ScrollView content slides beneath the pinned
      `closeRow` (top) and `bottomBlock` (CTA) with no backing, so stars/content
      visibly pass under the X button and through the button area. Fix:
      give `closeRow` and `bottomBlock` an opaque-ish backing that fades into the
      scroll area (e.g. `MooniColor.background` at ~0.9 with a 16 pt linear fade
      mask), and/or inset the stars field away from the top 60 pt / bottom 140 pt.

---

## 5. Remove the fake first-night morning screen

**What the user sees:** finish onboarding → immediately get the "Good morning /
\(pet) watched over you" check-in (`MorningCheckInView`) plus a Home "last
night" summary — built from a night that never happened.

**Root cause chain (all in `Mooni/Mooni/State/AppState.swift`):**
1. `MainTabView.task` → `runAutomationMaintenance` (:1014)
2. → `backfillMissedNights()` (:1044): for a brand-new user with zero entries it
   sets `earliest = now − 1 day` and seeds *last night* from the target schedule
   (`seedMissedNightEntry`, quality `.good`, "estimated from your target schedule").
3. → `evaluateMorningPrompt()` (:658) sees an unconfirmed night → pops
   `showMorningCheckIn`.
4. `autoSeedLastNightIfMissing()` (:969) can do the same on a 4 AM–2 PM open.

**Fix:** ✅ DONE (June 12)
- [x] `trackingStartedAt` persisted — set in both `completeOnboarding` overloads;
      existing installs migrate to their earliest entry's bedtime (or now).
- [x] `backfillMissedNights()`: bounded by `trackingStartedAt`; a user with zero
      entries gets nothing seeded — the first entry must come from a real signal.
- [x] `autoSeedLastNightIfMissing()` deleted (was dead code) — replaced by the
      sleep brain (`runSleepBrainEstimate`), which only works from real signals.
- [x] `SleepEntry.isScheduleBackfill` flag added; `entryNeedingMorningCheckIn`
      excludes backfills, so the morning check-in can never be triggered by an
      invented night. Completing a check-in clears the flag (user vouched for it).
- [ ] *(UI pass)* Home first-day state: when only a backfill/no entry exists, the
      "last night" hero shows a "Tonight is night one" card instead of fake stats —
      gate on `entry.isScheduleBackfill`, which now exists.

---

## 6. Sleep Brain — accurate, fully automated bed/wake detection

✅ IMPLEMENTED (June 12) — `Services/SleepSessionEngine.swift` (fusion engine +
lock-state store), `Services/MotionSleepAnalyzer.swift` (motion/pedometer
history), `AppState.runSleepBrainEstimate` (mechanism 11, wired into every
maintenance pass + wake-probe taps), `noteDayRollover` (new-day detection),
lock sampling in `BackgroundRefreshManager`, `NSMotionUsageDescription` added.
Still for the UI pass: motion pre-permission explainer screen, the lightweight
one-tap "You're up! Slept X → Y?" confirm sheet (high-confidence nights
currently reuse the full check-in), and DeviceActivity (Phase 2).

Goal: user never types "I'm going to sleep" or logs times. The app figures out
the night and, at most, asks for a one-tap confirm. Much of the plumbing
already exists (scenePhase estimator, onset probes, wake probes, daily
safety-net probes, BG refresh, HealthKit import) — this organizes it into one
engine and adds the two highest-value missing signals.

### 6.1 Signals, ranked by trust

| # | Signal | Source | Status |
|---|--------|--------|--------|
| 1 | HealthKit sleep samples (Watch/iPhone) | `HealthKitManager` | exists (Pro) |
| 2 | Explicit taps: bed / "I'm awake" / probe responses | `AppState`, `NotificationManager` | exists |
| 3 | **Motion history (NEW)** — iOS keeps ~7 days of `CMMotionActivityManager` + `CMPedometer` history. Query it each morning: longest stationary block overlapping the night window ⇒ bed/wake bounds; first steps after 4 AM ⇒ hard wake floor. No background running needed — it's a retrospective query. Requires Motion & Fitness permission (new onboarding ask). | new `MotionSleepAnalyzer` | **new** |
| 4 | Screen activity: last app-background before midnight, first foreground after 4 AM | `ActivitySleepEstimator` | exists |
| 5 | **Lock-state sampling (NEW)** — during each `BGAppRefresh` wake-up overnight, record `(timestamp, UIApplication.isProtectedDataAvailable)`. Device locked at 3 AM ⇒ asleep-consistent sample. Sparse but free. | extend `BackgroundRefreshManager` | **new** |
| 6 | Onset probes ("still awake?" at +15/30/45) — taps push the sleep-onset lower bound | exists | exists |
| 7 | Target schedule | prior only — may *narrow* an estimate, never *create* a displayed night (see §5) | exists |

Screen-Time/DeviceActivity (true device-pickup data) needs the FamilyControls
entitlement + a DeviceActivityMonitor extension and Apple approval — park it as
an explicit **Phase 2** opt-in ("let SleepOwl watch screen activity around your
sleep window"); the events it reports (usage inside the sleep window) would add
night-time-pickup detection and exact last-use/first-use times.

### 6.2 The engine

New `Services/SleepSessionEngine.swift`:
- Runs inside `runAutomationMaintenance` (so: every launch, foreground, BG refresh).
- For the most recent night, gathers all available signals and computes
  `bedEstimate`, `wakeEstimate`, `confidence (0–1)` — weighted-overlap fusion:
  HealthKit wins outright; otherwise intersect motion-stationary block with
  screen-quiet block; probe taps clamp the bounds; schedule prior only breaks ties.
- Writes the entry with `source` + `confidence`; UI shows "auto-tracked" vs
  "estimated — tap to fix" under a threshold (e.g. < 0.6).
- All existing Pro gating stays as-is.

### 6.3 "Is it the next day / are they awake?" brain

- New day = `now.dayKey != lastSeenDayKey && hour ≥ 4`. Check it on every
  foreground, notification tap, and BG refresh (store `lastSeenDayKey`).
- First qualifying event after a tracked night ⇒ **instant wake flow**: a single
  lightweight sheet — "You're up! Slept 11:32 PM → 7:14 AM?" with **Confirm** /
  **Adjust**. High-confidence nights skip straight to the sleep story; the long
  multi-question check-in only appears when confidence is low or the user taps
  Adjust.
- Notifications (mostly already built — keep cadence, tighten behavior):
  - onset probes +15/30/45 min (exists)
  - wake probes at −60/−30/0/+30/+60 around target wake (exists)
  - daily safety-net probes + 2 h catch-up (exists)
  - NEW: when a wake probe fires *and* motion/lock samples already say "awake"
    (steps recorded, device unlocked), make the notification the wake-confirm
    itself: "Tap = I'm awake" action records wake at tap time and opens the story.
- Evening side: `autoArmNightIfDue` (exists) already arms on phone-down after
  19:00; feed its `sleepStartedAt` from `ActivitySleepEstimator.pendingEstimatedSleepStart`
  (already wired) and later refine with the morning motion query.

### 6.4 New permission ask

Add a Motion & Fitness pre-permission screen (mirroring the notification one)
to onboarding, positioned with the auto-tracking pitch screens — it's the
single highest-accuracy signal that works with zero user effort and no Watch.

---

## 7. Verification pass (after implementation)

- Build per the usual `DEVELOPER_DIR` + `xcodebuild` + `simctl` setup.
- Fresh install → complete onboarding mid-day → assert: no morning check-in, no
  fake "last night", Home shows night-one state.
- Screenshot: plan-computing screen, plan-reveal ring, widget showcase vs real
  widget gallery (`simctl` widget preview), paywall (button legibility, logo,
  top/bottom edges).
- Simulate next-day: advance simulator clock / relaunch after dayKey change →
  wake-confirm sheet appears, entry created from estimator interval.

## Execution order

1. §1 + §2 (ring + glow cleanup — quick, high-visibility)
2. §4 paywall polish
3. §3 widget redesign + preview parity
4. §5 fake-night removal
5. §6 sleep brain (engine + motion analyzer + lock sampling + wake flow)
6. §7 verify everything
