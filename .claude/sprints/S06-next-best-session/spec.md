# Sprint 6 — Next Best Session Engine v1 / Smart Comeback

> Detailed implementation spec for coding agents.
> Reference: `.claude/GYMTRACK.md` §9 Sprint 6, §10 Core Algorithms (SmartSessionAdvisor, ComebackRamp, Progressive Overload).

---

## Overview

**Goal:** Ship the first public proof of the Next Best Session Engine: when the user returns after 7+ days off, the app shows a Comeback Card on Today, the workout session UI is decorated with Easing Back badges, weights and set counts are reduced per the SmartSessionAdvisor rules, a per-exercise "How did that feel?" picker captures effort, and the ramp service decides the next session's adjustment. A double-haptic moment fires when the user regains their pre-gap baseline.

**Primary acceptance test:** Force the latest completed session to be 15 days old (e.g. by editing the row's `ended_at` in Supabase). Open the app → TodayView shows a `ComebackCardView` with bilingual emotional copy ("Welcome back / ยินดีต้อนรับกลับ — Today's adjusted session: −20%, one fewer set"). Start the workout → each comeback-eligible exercise on `WorkoutExercisePageView` shows an EasingBackBadge, the baseline line ("Baseline: 80 kg × 8"), and pre-filled targets at 64 kg × 2 sets instead of 80 kg × 3 sets. Finish the first exercise → `HowDidThatFeelPicker` appears. Pick "Just right" → all set RPEs back-fill to 7.5, picker dismisses. Finish workout → session uploads. Reopen Today → `ComebackRampService` decision is visible on next-day card ("+10% next time"). Complete enough sessions to clear baseline → "Baseline regained" moment fires (double haptic) and Today exits comeback mode.

**Effort estimate:** Complex (4 new pure-Swift services with full test coverage + 2 new UI components + comeback-mode wiring across Today and Workout flows + localization for two emotional moments).

**Dependencies:** Sprints S01–S05 + S05p complete. Reuses `WorkoutRepository.fetchHistory(limit:)` / `fetchSets(sessionId:)`, `ProgramRepository.fetchActive()`, `TodayViewModel` + `TodayData`, `WorkoutSessionViewModel` + `WorkoutExercisePageView`, `LastSessionLookupService` (Sprint S05p), `AppPreferences` + `WeightUnit` (Sprint S05), and the `AppError` / `ViewState` pipeline.

---

## 1. Requirements

### Must Have

```text
☐ NextBestSessionEngine
    Coordinator service. Combines active program, recent sessions,
    derived comeback state. Outputs TodayRecommendation:
      mode: .normal | .comeback(stage)
      programDay
      perExerciseAdjustments: [UUID: ExerciseAdjustment]
      reason: localized key (e.g. "comeback.reason.14d")
    Pure Swift, no I/O, fully unit-tested.

☐ SmartSessionAdvisor
    Pure Swift rule table from GYMTRACK §10 (0–2/3–6/7–13/14–20/21–41/42+ day windows).
    Input: daysSinceLastCompleted, recentRPEFeedback (optional).
    Output: ComebackStage with weightMultiplier, setDelta, copyKey.
    Fully unit-tested across all six bands + edge cases (0 days, missing baseline,
    weekend boundaries).

☐ ComebackRampService
    Pure Swift. Given the user's HowDidThatFeel mapped RPE for an exercise's
    most-recent comeback session, returns the next-session ramp:
      RPE < 6.5   → +15%
      RPE 6.5–7.5 → +10%
      RPE 7.5–8.5 → hold weight, add 1 rep target
      RPE ≥ 8.5   → −5%
    Also returns the "exit comeback" decision when current weight ≥ baseline
    AND RPE ≤ 7.5 → one consolidation session, then resume normal.
    Fully unit-tested.

☐ ProgressiveOverloadEngine (read-only display this sprint)
    Pure Swift. Given an exercise's last 2–3 completed sessions, returns a
    nextWeightSuggestion: Double? (in kg). Surfaces on the WorkoutExercisePageView
    header as a muted "Try 77.5 kg" hint. Does NOT pre-fill SetRowView and does
    NOT mutate ProgramExercise.targetWeight. Suggestion is null if confidence
    is low (<2 prior sessions). Fully unit-tested.

☐ AnalyticsTracking protocol + NoopAnalytics + DebugConsoleAnalytics
    Minimal protocol surface:
      func track(_ event: AnalyticsEvent)
    AnalyticsEvent is an enum with four cases this sprint:
      .comebackCardShown, .comebackSessionStarted,
      .comebackSessionFinished, .comebackExitBaselineReached
    Wired through environment / DI. Default in Release = NoopAnalytics;
    Debug builds use DebugConsoleAnalytics (os_log). Sprint 7 swaps in
    the real TelemetryDeck adapter without caller changes.

☐ ComebackCardView (TodayView)
    Semantic standout card. Bilingual emotional moment (TH+EN side-by-side
    per design system Bilingual copy rule). Shows: greeting, adjusted-session
    summary ("−20% · one fewer set · 14 days off"), Start CTA.
    Tappable area = full card; CTA opens WorkoutSessionScreen with comeback
    flag set. Tap target ≥ 48pt.
    No custom colors — semantic system colors only.

☐ WorkoutSessionView / WorkoutExercisePageView comeback mode
    When TodayRecommendation.mode is .comeback:
      • EasingBackBadge above each affected exercise's set list.
        Copy: "Easing back · ผ่อนกลับมา"
        Color: semantic .secondary background, no custom palette.
      • Baseline reference row (extends Sprint S05p LastSessionReference.Label.baseline):
        "Baseline: 80 kg × 8, 8, 7"
        Uses the same row component shipped in S05p; this sprint wires the
        .baseline branch.
      • Adjusted set count and weight defaults applied via ViewModel
        (display-only, original ProgramExercise rows untouched).

☐ HowDidThatFeelPicker
    Only visible in comeback mode. Triggers on Finish Exercise tap:
      [Easy] [Just right] [Hard]
    Tap maps to RPE 6.0 / 7.5 / 9.0 and back-fills ALL completed sets'
    rpe column for that exercise via WorkoutRepository.updateSets(ids:rpe:).
    Skip button allowed — RPE values remain whatever user already entered
    (or null).
    Tap target ≥ 48pt per button.

☐ Baseline regained moment
    Fires inside SetRowView completion handler:
      when set's actual weight (in kg, normalized) ≥ pre-gap baseline weight
      AND set's actual reps ≥ baseline reps
      AND we are currently in comeback mode
      → trigger UIImpactFeedbackGenerator(.medium) twice (double haptic),
        emit AnalyticsEvent.comebackExitBaselineReached,
        update ViewModel.baselineRegainedThisSession = true.
    On session finish: if baselineRegainedThisSession, mark next Today load
    to drop comeback mode (the derivation already handles this from the
    SmartSessionAdvisor rules; this flag just primes the message).

☐ All visible strings localized in Thai and English
☐ All errors flow through AppError / ViewState
☐ Build + tests pass on iPhone 17e simulator
```

### Out of Scope

```text
✗ StallDetector + DeloadAdvisor (Sprint 7)
✗ TelemetryDeck SDK package + real network sends (Sprint 7 swap)
✗ Injury substitution / Substitute / Defer (Sprint 9)
✗ Recovery / HRV (Sprint 11)
✗ Cross-session weight pre-fill — engine only displays suggestions
✗ Database schema changes — comeback mode is derived from history
✗ ProgramExercise.targetWeight mutation — comeback adjustments are
   ViewModel-only overlays
✗ Editing past sessions to test comeback (manual Supabase row edit OK)
✗ Bilingual copy rule for ALL UI — bilingual side-by-side limited to the
   ComebackCardView and BaselineRegainedToast per §6 Design System
```

---

## 2. Existing Foundation To Reuse

```text
Gymbros/Data/Repository/WorkoutRepository.swift        fetchHistory(limit:) + fetchSets(sessionId:); ADD updateSets(ids:rpe:)
Gymbros/Data/Repository/ProgramRepository.swift        fetchActive()
Gymbros/Data/Services/StreakService.swift              prior-art for pure-Swift services
Gymbros/Data/Services/LastSessionLookupService.swift   reference-row lookup (Sprint S05p)
Gymbros/Model/WorkoutSession.swift                     startedAt/endedAt/isComplete
Gymbros/Model/WorkoutSet.swift                         rpe column already exists
Gymbros/Model/Program.swift + ProgramDay.swift + ProgramExercise.swift
Gymbros/Model/Enums/WeightUnit.swift                   kg/lb
Gymbros/Core/AppPreferences.swift                      shared weight-unit state
Gymbros/Core/WeightUnitFormatting.swift                kg/lb conversion + display
Gymbros/Core/ErrorHandling/AppError.swift              .api / .network / etc.
Gymbros/Core/ErrorHandling/ViewState.swift             .idle / .loading / .success / .empty / .error
Gymbros/Core/ErrorHandling/ErrorMapper.swift           single mapper
Gymbros/Presentation/Today/TodayViewModel.swift        wire comeback decision into TodayData
Gymbros/Presentation/Today/TodayView.swift             surface ComebackCardView when mode == .comeback
Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift   comeback-aware defaults + RPE back-fill
Gymbros/Presentation/Workout/WorkoutExercisePageView.swift   EasingBackBadge + baseline row + picker
Gymbros/Presentation/Workout/WorkoutSessionScreen.swift      pass-through of TodayRecommendation
Gymbros/Presentation/Workout/SetRowView.swift                baseline-regained haptic hook
Gymbros/Resources/Localizable.xcstrings
```

---

## 2.1 Spec Lock Decisions

Task 0 of the implementation plan locks these before parallel work starts:

1. **Telemetry layer:** `AnalyticsTracking` protocol in `Data/Services/Analytics/`. `NoopAnalytics: AnalyticsTracking` is the default; `DebugConsoleAnalytics: AnalyticsTracking` is auto-selected via `#if DEBUG`. `AnalyticsEvent` is a Swift enum with the four cases listed in Requirements. Sprint 7 adds `TelemetryDeckAnalytics: AnalyticsTracking` without touching call-sites.

2. **HowDidThatFeel mapping & back-fill:**
   ```swift
   enum HowDidThatFeel { case easy, justRight, hard
       var rpe: Double { switch self {
           case .easy: 6.0; case .justRight: 7.5; case .hard: 9.0 } }
   }
   ```
   On Finish Exercise tap in comeback mode → present `HowDidThatFeelPicker` modal. On selection, `WorkoutSessionViewModel.applyFeedback(_:to:)` calls `WorkoutRepository.updateSets(ids: [UUID], rpe: Double)` with the IDs of all completed sets for that `programExerciseId` in the current session. Skip button is allowed; user can also dismiss the picker (treated as Skip — no RPE write).

3. **Comeback mode derivation (no schema):** Each `TodayViewModel.fetch()` call:
   ```text
   let lastSession = completed.first
   let daysSince = floor((now - lastSession.endedAt) / 86400)
   let stage = SmartSessionAdvisor.stage(forDaysSinceLast: daysSince)
   if stage.isComeback {
       let baselines = baselineWeights(per programExerciseId,
                                       fromSessionsBefore: lastSession.endedAt)
       mode = .comeback(stage: stage, baselines: baselines)
   } else {
       mode = .normal
   }
   ```
   `baselineWeights(...)` = highest completed weight per `programExerciseId` from sessions whose `endedAt < gapStart`. Stored on `TodayData` and passed forward into `WorkoutSessionScreen`.

4. **Comeback adjustment overlay (display-only):**
   ```swift
   struct ExerciseAdjustment {
       let originalTargetWeight: Double?   // ProgramExercise.targetWeight
       let adjustedTargetWeight: Double?   // applied by SmartSessionAdvisor
       let originalSets: Int
       let adjustedSets: Int               // originalSets - stage.setDelta, min 1
       let baselineWeight: Double?
       let baselineReps: [Int]
   }
   ```
   `WorkoutSessionViewModel` reads adjustments when it builds its in-memory exercise pages. The pre-fill chain for set 1 weight becomes `adjustedTargetWeight ?? targetWeight ?? lastLogged ?? blank`. Set 2+ pre-fills still use the previous set's actual logged values per Sprint 3.

5. **Baseline regained detection:** Fires inside `SetRowView` `onCompleted` only when:
   ```text
   viewModel.mode.isComeback == true
   AND set.actualWeightKg >= adjustment.baselineWeight
   AND set.actualReps >= adjustment.baselineReps.first
   AND !viewModel.baselineRegainedThisSession
   ```
   Sets `baselineRegainedThisSession = true` (idempotent for the session), triggers `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` twice (50ms apart), and emits `AnalyticsEvent.comebackExitBaselineReached`. Visible toast is optional — copy locked here but UI shipped only if time permits (see §9 Stretch).

6. **ProgressiveOverloadEngine confidence rule:** Returns `nil` if fewer than 2 completed sessions exist for the exercise OR if the last session had RPE > 8.0 (don't push when fatigued). In comeback mode, the engine is NOT called — `ComebackRampService` owns weight decisions.

7. **NoopAnalytics is the default in Release.** Production builds emit nothing to the network this sprint; only DEBUG logs to console. This is intentional and revisited in Sprint 7.

---

## 3. Product Flow

```text
App launch → authenticated → RootView → TabView

TodayView .task:
  TodayViewModel.load()
    → ProgramRepository.fetchActive()
    → WorkoutRepository.fetchHistory(limit: 50)
    → NextBestSessionEngine.recommend(
          program: …, history: …, now: .now)
    → TodayData.mode = .normal or .comeback(stage, baselines, adjustments)

TodayView render:
  if data.mode.isComeback:
    ComebackCardView (bilingual emotional copy)
      → analytics.track(.comebackCardShown)  (fire once per appearance)
      → Start CTA → WorkoutSessionScreen(programDayId:, recommendation:)
  else:
    standard next-workout card (unchanged from Sprint 4)

WorkoutSessionScreen .task:
  WorkoutSessionViewModel.startSession(recommendation:)
    → analytics.track(.comebackSessionStarted) if recommendation.mode.isComeback
    → builds per-exercise pages with ExerciseAdjustment overlay
    → loads lastSessionReferences AND baselineReferences (S05p + new)

WorkoutExercisePageView (per exercise, comeback mode):
  • EasingBackBadge
  • Baseline row: "Baseline: 80 kg × 8, 8, 7" (S05p .baseline label)
  • Adjusted defaults: set 1 pre-fills adjustedTargetWeight
  • Adjusted set count: only N sets render where N = adjustedSets

User completes a set → SetRowView.onComplete:
  → ViewModel.markSetCompleted(...)
  → if comeback AND set ≥ baseline → double-haptic + analytics.track(.comebackExitBaselineReached)

User taps Finish Exercise → in comeback mode:
  → HowDidThatFeelPicker modal
  → User taps Easy / Just right / Hard / Skip
  → ViewModel.applyFeedback(.justRight, to: programExerciseId)
       → WorkoutRepository.updateSets(ids: completedSetIds, rpe: 7.5)
       → ComebackRampService caches ramp decision for next session
  → page locks (existing Sprint 3 behavior)

User taps Finish Workout:
  → existing batch upload (Sprint 4)
  → analytics.track(.comebackSessionFinished) if recommendation.mode.isComeback
  → returns to Today

Reopen TodayView:
  → recommend() recomputes; if baselineRegained or RPE ≤ 7.5 across
    recent comeback session AND weight ≥ baseline → mode = .normal
    AND next-workout card shows ComebackRampService preview
    ("Next time: +10%")
```

---

## 4. New Services

All under `Gymbros/Data/Services/`. Pure Swift, no I/O, fully unit-tested.

### 4.1 NextBestSessionEngine

```swift
struct TodayRecommendation: Equatable {
    enum Mode: Equatable {
        case normal
        case comeback(stage: ComebackStage,
                      adjustments: [UUID: ExerciseAdjustment])
    }
    let mode: Mode
    let programDay: ProgramDay?
    let reasonKey: String        // localization key e.g. "comeback.reason.14d"
}

struct NextBestSessionEngine {
    let advisor: SmartSessionAdvisor
    let ramp: ComebackRampService
    let overload: ProgressiveOverloadEngine

    func recommend(
        program: Program?,
        history: [WorkoutSession],
        sets: [UUID: [WorkoutSet]],   // sessionId → sets, already fetched
        now: Date
    ) -> TodayRecommendation
}
```

Algorithm:
1. Filter `history` to completed, newest-first.
2. If `program == nil` or no completed history → return `.normal` with `programDay = program?.days.first`.
3. Compute `daysSince = floor((now - lastCompleted.endedAt) / 86400)`.
4. `stage = advisor.stage(forDaysSinceLast: daysSince, recentRPEFeedback: …)`.
5. If `stage.isComeback`:
   - Build `baselines = max weight per programExerciseId, from sets where session.endedAt < gapStart`.
   - For each exercise in `nextDay`: build `ExerciseAdjustment` (apply `stage.weightMultiplier`, `stage.setDelta`, attach baseline).
   - Build ramp preview for next session via `ramp.preview(forExercises:...)` (used for next-card teaser).
6. Else `.normal`, with optional `overload.nextWeightSuggestion(per exercise)` decorating the data for read-only display.

### 4.2 SmartSessionAdvisor

```swift
struct ComebackStage: Equatable {
    let bandKey: String        // localization key: "comeback.band.7_13" etc.
    let weightMultiplier: Double    // 1.0 = unchanged; 0.8 = -20%
    let setDelta: Int               // -1 means drop a set
    let isComeback: Bool
}

struct SmartSessionAdvisor {
    func stage(forDaysSinceLast days: Int) -> ComebackStage
}
```

Mapping (from §10):
```
0–2  : normal       (1.00, 0, false)
3–6  : normal       (1.00, 0, false)   // reschedule logic is presentation layer
7–13 : comeback     (0.90, -1, true)
14–20: comeback     (0.80, -1, true)
21–41: comeback     (0.70, -1, true)
42+  : near-restart (0.50, -1, true)
```

### 4.3 ComebackRampService

```swift
enum RampDecision: Equatable {
    case increase(percent: Double)   // +15%, +10%
    case holdAddRep
    case decrease(percent: Double)   // -5%
    case exitComeback                // consolidation passed, normal next
}

struct ComebackRampService {
    func decide(
        lastComebackRPE: Double?,
        currentWeight: Double,
        baselineWeight: Double?
    ) -> RampDecision
}
```

Rules (from §10):
```
if currentWeight >= baselineWeight && lastRPE <= 7.5  → .exitComeback
if lastRPE == nil                                     → .holdAddRep (no signal)
if lastRPE < 6.5                                      → .increase(15)
if 6.5..<7.5                                          → .increase(10)
if 7.5..<8.5                                          → .holdAddRep
else                                                  → .decrease(5)
```

### 4.4 ProgressiveOverloadEngine (read-only this sprint)

```swift
struct ProgressiveOverloadEngine {
    func nextWeightSuggestion(
        forExerciseId: UUID,
        recentSessions: [WorkoutSession],
        sets: [UUID: [WorkoutSet]]
    ) -> Double?
}
```

Rules (from §10, simplified):
```
Confidence gate: need ≥2 completed sessions in the last 60 days.
If last session's top-set RPE > 8.0  → return nil (don't push)
If last session's top-set RPE ≤ 7.0 AND target reps achieved
                                     → return lastWeight + 2.5
If last session's top-set RPE 7.5..8.0 → return lastWeight (hold)
else                                  → return nil
```

### 4.5 AnalyticsTracking (under `Data/Services/Analytics/`)

```swift
enum AnalyticsEvent {
    case comebackCardShown
    case comebackSessionStarted
    case comebackSessionFinished
    case comebackExitBaselineReached
}

protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

struct NoopAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}

#if DEBUG
struct DebugConsoleAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {
        os_log("analytics: %{public}@", String(describing: event))
    }
}
#endif
```

Injected through ViewModels' init; root composition picks `DebugConsoleAnalytics` in `#if DEBUG`, otherwise `NoopAnalytics`. Sprint 7 replaces the Release default with `TelemetryDeckAnalytics`.

---

## 5. Repository Changes

### 5.1 WorkoutRepository.updateSets(ids:rpe:)

Add to `WorkoutRepositoryProviding`:

```swift
func updateSets(ids: [UUID], rpe: Double) async throws
```

Implementation: single PATCH to `workout_sets` filtered by `id in (...)`, body `{ "rpe": <value> }`, `returning: .minimal`. Errors mapped through `ErrorMapper` to `AppError`. Empty `ids` is a no-op (return immediately without a network call). New test: `WorkoutRepositoryPayloadTests.updateSetsRPEPayload`.

No other repository changes.

---

## 6. ViewModel Changes

### 6.1 TodayViewModel

- Holds `let engine: NextBestSessionEngine` (injected, default constructed).
- Holds `let analytics: AnalyticsTracking` (injected, default = `DebugConsoleAnalytics` in DEBUG, `NoopAnalytics` otherwise).
- `TodayData` gains:
  ```swift
  var recommendation: TodayRecommendation
  var rampPreview: [UUID: RampDecision]    // empty in normal mode
  ```
- On successful load with `recommendation.mode.isComeback`, `TodayView` body calls `analytics.track(.comebackCardShown)` exactly once via `.onAppear` (gated by a `@State var didLogCardShown`).
- Start CTA passes the full `TodayRecommendation` into `WorkoutSessionScreen`.

### 6.2 WorkoutSessionViewModel

- New init parameter: `recommendation: TodayRecommendation` (defaults to `.normal`).
- Stores `let adjustments: [UUID: ExerciseAdjustment]`.
- Stores `let baselines: [UUID: (weight: Double, reps: [Int])]` (subset of adjustments).
- `mode` computed property exposes `.normal | .comeback`.
- Set 1 default pre-fill chain (in `pageDefaults(for:)`):
  ```text
  adjustments[programExerciseId]?.adjustedTargetWeight
  ?? programExercise.targetWeight
  ?? lastLoggedWeight
  ?? blank
  ```
- Set count visible per exercise = `adjustments[id]?.adjustedSets ?? programExercise.targetSets`.
- New methods:
  ```swift
  func applyFeedback(_ feel: HowDidThatFeel, to programExerciseId: UUID) async
  func checkBaselineRegained(for set: WorkoutSet)   // called by SetRowView onCompleted
  ```
- `applyFeedback`: collects all completed-set IDs for that `programExerciseId`, calls `workoutRepository.updateSets(ids:rpe:)`, updates in-memory set rows so the displayed RPE matches. Errors flow through `transientError: AppError?`.
- `checkBaselineRegained`: idempotent per session; triggers double-haptic + analytics event.
- `finishSession`: on success, emits `.comebackSessionFinished` if mode was comeback.

---

## 7. UI Requirements

### 7.1 ComebackCardView (new) — `Presentation/Today/Components/`

```text
Layout:
  VStack(spacing: 12) {
    HStack(alignment: .top) {
      VStack(alignment: .leading) {
        Text("today.comeback.welcome_back.th")   // ยินดีต้อนรับกลับ
        Text("today.comeback.welcome_back.en")   // Welcome back
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    Text(recommendation.reasonKey)              // "−20% · one fewer set"
      .font(.subheadline.monospacedDigit())
      .foregroundStyle(.secondary)
    Text("today.comeback.subtitle")             // "Today's adjusted session"
    Button { onStart() } label: { Text("today.comeback.start") }
      .buttonStyle(.borderedProminent)
      .frame(minHeight: 48)
  }
  .padding()
  .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
```

Bilingual rule per §6: both languages visible. No custom colors. Tap target ≥ 48pt.

### 7.2 EasingBackBadge (new) — `Presentation/Workout/Components/`

```text
HStack(spacing: 6) {
  Image(systemName: "arrow.uturn.backward")
  Text("workout.comeback.easing_back")   // "Easing back · ผ่อนกลับมา"
}
.font(.caption.weight(.semibold))
.padding(.horizontal, 10)
.padding(.vertical, 4)
.background(Capsule().fill(Color(.tertiarySystemFill)))
.foregroundStyle(.secondary)
```

Placed above the set list in `WorkoutExercisePageView` when `mode.isComeback`.

### 7.3 HowDidThatFeelPicker (new) — `Presentation/Workout/Components/`

```text
Presented as .sheet(isPresented:) when user taps Finish Exercise AND mode == .comeback.

VStack(spacing: 20) {
  Text("workout.comeback.feel.title")          // "How did that feel?"
  HStack(spacing: 12) {
    feelButton(.easy,        key: "workout.comeback.feel.easy")
    feelButton(.justRight,   key: "workout.comeback.feel.just_right")
    feelButton(.hard,        key: "workout.comeback.feel.hard")
  }
  .frame(minHeight: 48)
  Button("workout.comeback.feel.skip") { dismiss() }
    .buttonStyle(.borderless)
}
.padding()
.presentationDetents([.medium])

Each feelButton:
  Button { onSelect(feel) } label: {
    VStack { Image(systemName: feel.symbolName); Text(localizedKey) }
      .frame(maxWidth: .infinity, minHeight: 64)
  }
  .buttonStyle(.bordered)
```

Symbols: `.easy` → `"face.smiling"`; `.justRight` → `"checkmark.circle"`; `.hard` → `"flame"`. No custom palette.

### 7.4 WorkoutExercisePageView changes

Above the existing set list (and below the existing S05p reference row):
- `if viewModel.mode.isComeback` → `EasingBackBadge()`.
- The reference row uses `LastSessionReference.Label.baseline` when baseline data is present (this is the S05p seam being filled this sprint).

Hint line (normal mode only) below the page header:
- `if let suggestion = adjustment.overloadHint` → `Text("workout.overload.hint", suggestion)` in `.secondary`.

### 7.5 SetRowView changes

- Add optional `onCompletedWithDetails: (WorkoutSet) -> Void` callback (or use existing onCompleted with viewmodel hook).
- In comeback mode, parent calls `viewModel.checkBaselineRegained(for:)` after marking a set complete.

### 7.6 Baseline regained moment

- Double medium haptic (`UIImpactFeedbackGenerator(style: .medium)` fired twice, 50ms apart).
- Optional `BaselineRegainedToast` (stretch — see §9). Bilingual copy: "Baseline regained · กลับมาที่จุดเดิม".
- Analytics event fires regardless of whether the toast is shipped.

---

## 8. Localization

Add complete Thai and English copy for these key families. Final wording confirmed at Task 0:

```text
today.comeback.welcome_back
  en: "Welcome back"
  th: "ยินดีต้อนรับกลับ"

today.comeback.subtitle
  en: "Today's adjusted session"
  th: "เซสชั่นที่ปรับมาให้แล้ววันนี้"

today.comeback.start
  en: "Start"
  th: "เริ่ม"

comeback.reason.7_13
  en: "−10% · one fewer set · %d days off"
  th: "−10% · ลดเซ็ตลง 1 · พัก %d วัน"

comeback.reason.14_20
  en: "−20% · one fewer set · %d days off"
  th: "−20% · ลดเซ็ตลง 1 · พัก %d วัน"

comeback.reason.21_41
  en: "−30% · one fewer set · ramp 10%/session"
  th: "−30% · ลดเซ็ตลง 1 · เพิ่มทีละ 10%/เซสชั่น"

comeback.reason.42_plus
  en: "−50% · slow restart"
  th: "−50% · เริ่มกลับมาแบบช้า ๆ"

workout.comeback.easing_back
  en: "Easing back"
  th: "ผ่อนกลับมา"

workout.comeback.feel.title
  en: "How did that feel?"
  th: "รู้สึกยังไงบ้าง?"

workout.comeback.feel.easy
  en: "Easy"
  th: "สบาย"

workout.comeback.feel.just_right
  en: "Just right"
  th: "พอดี"

workout.comeback.feel.hard
  en: "Hard"
  th: "หนัก"

workout.comeback.feel.skip
  en: "Skip"
  th: "ข้าม"

workout.comeback.baseline_regained
  en: "Baseline regained"
  th: "กลับมาที่จุดเดิม"

workout.overload.hint
  en: "Try %@ next set"
  th: "ลอง %@ เซ็ตถัดไป"

accessibility.today.comeback_card
  en: "Comeback card. %@"
  th: "การ์ดกลับมาเทรน %@"

accessibility.workout.easing_back
  en: "Easing back"
  th: "ผ่อนกลับมา"
```

---

## 9. Stretch (only if implementation time permits)

- `BaselineRegainedToast` (overlay banner, 2.5s auto-dismiss, bilingual copy).
- Today next-workout card shows the `RampDecision` preview chip ("Next time: +10%").
- Pre-fetched analytics-event call site coverage assertion test.

These are explicitly OPTIONAL. The sprint completes without them.

---

## 10. Testing And Acceptance

### Automated tests

**SmartSessionAdvisorTests:**
- Returns `.normal` for 0, 2, 6 days.
- Returns comeback band for 7, 13, 14, 20, 21, 41, 42 days (exact mapping).
- Boundary tests at 6→7 and 41→42 day transitions.
- Negative days input clamped to 0.

**ComebackRampServiceTests:**
- `.exitComeback` when weight ≥ baseline AND RPE ≤ 7.5.
- `.holdAddRep` when no RPE provided.
- `.increase(15)` when RPE < 6.5.
- `.increase(10)` when 6.5 ≤ RPE < 7.5.
- `.holdAddRep` when 7.5 ≤ RPE < 8.5.
- `.decrease(5)` when RPE ≥ 8.5.
- Missing baseline never crashes; returns `.holdAddRep`.

**ProgressiveOverloadEngineTests:**
- Returns nil with 0, 1 prior sessions.
- Returns lastWeight + 2.5 when last RPE ≤ 7.0 and target reps hit.
- Returns lastWeight (hold) when 7.5 ≤ RPE ≤ 8.0.
- Returns nil when RPE > 8.0.
- Returns nil when most-recent session is >60 days old.

**NextBestSessionEngineTests:**
- Day-14 history yields `.comeback` with 0.80 multiplier and -1 set delta.
- Day-2 history yields `.normal`.
- Empty history yields `.normal` with `programDay = first`.
- No active program yields `.normal` with `programDay = nil`.
- Adjustments preserve `originalSets` even when adjusted clamps to 1.

**WorkoutRepositoryPayloadTests:**
- `updateSets(ids: [], rpe: ...)` is a no-op (no network).
- `updateSets(ids: [a,b], rpe: 7.5)` encodes correct PATCH body.

**WorkoutSessionViewModelTests (additions):**
- Starting a session with a comeback recommendation sets adjusted defaults.
- `applyFeedback(.justRight, to:)` calls `updateSets` with completed-set IDs and rpe 7.5.
- `checkBaselineRegained` is idempotent per session (only fires the first time threshold met).
- `finishSession` emits `.comebackSessionFinished` when mode was comeback.

**TodayViewModelTests (additions):**
- Recent history 15 days old produces `recommendation.mode.isComeback` with `.14_20` band and `0.80` multiplier.
- `analytics.track(.comebackCardShown)` is called exactly once per Today appearance with comeback mode (verify with spy).

### Manual smoke test

```text
0. SETUP — in Supabase Studio, edit the most recent workout_sessions row:
   ended_at = now - 15 days. Make sure the row's user_id matches the
   currently signed-in user.

1. Cold-start the app and sign in.
2. TodayView shows ComebackCardView with both TH and EN greeting and
   reason copy "−20% · one fewer set · 15 days off" (Thai equivalent if
   device language = Thai).
3. Tap Start. analytics console log shows `comebackCardShown` then
   `comebackSessionStarted`.
4. Each WorkoutExercisePageView shows:
   • EasingBackBadge above the set list.
   • Baseline row e.g. "Baseline: 80 kg × 8" (uses S05p reference component
     with .baseline label).
   • Pre-filled set 1 weight at 80 × 0.8 = 64 kg.
   • One fewer set than the program (e.g. 2 sets instead of 3).
5. Complete a set. Standard haptic; no baseline-regained moment yet.
6. Add a set and enter 80 kg × 8 (= baseline). Complete it.
   → Double medium haptic fires. Console logs
     `comebackExitBaselineReached`.
7. Tap Finish Exercise. HowDidThatFeelPicker appears. Pick "Just right".
   → Picker dismisses. The just-completed set's RPE field shows 7.5.
   → Page locks (Sprint 3 behavior).
8. Complete remaining exercises (with or without HowDidThatFeel).
9. Tap Finish Workout. Console logs `comebackSessionFinished`.
10. Reopen Today. The next-day card shows "+10% next time" hint
    (or no comeback card if baselineRegained AND ramp says exit).
11. Switch device to Thai language. Restart. Verify ComebackCardView,
    EasingBackBadge, HowDidThatFeelPicker, and baseline row all render
    with Thai copy.
12. Verify Reduce Motion (Settings > Accessibility) does not affect
    haptics (only animations from S05p are gated). Baseline haptic
    still fires.
```

### Build and test

```bash
xcodebuild test \
  -project Gymbros.xcodeproj \
  -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e'
```

### GYMTRACK + STANDUP updates after sprint

- Update GYMTRACK.md §9 Sprint Tracking row 6 status when sprint starts (`⏳`) and again on completion (`✅`).
- Update STANDUP.md with HEAD SHA, sprint outcome, and next-up = "Sprint 7 — Onboarding + Templates + i18n + Brain Polish".
