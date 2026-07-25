# Sprint S06 — Next Best Session Engine v1 / Smart Comeback — Implementation Plan

> Spec: `.claude/sprints/S06-next-best-session/spec.md` (read it first — all algorithm
> rules, copy, and acceptance tests live there). This plan is the task checklist and
> records wiring decisions against the current codebase.

## CURRENT STATUS

| Field | Value |
|---|---|
| Status | ✅ Sprint complete and committed; pending manual smoke test (user-driven) |
| Last commit | `e1859b6` (2026-06-20, bundled with local-first sessions) |
| Known deviations | See "Locked wiring decisions" below (D1–D8) |
| Next step | Manual smoke test (see STANDUP.md "Next up" for the checklist) |

## Locked wiring decisions (deltas vs. spec text)

- **D1 — Baseline-regained hook lives in the ViewModel, not SetRowView.** Spec §7.5 says the parent calls `checkBaselineRegained` after a set completes; `WorkoutSessionViewModel.completeSet(setId:)` already owns that moment, so the check runs inside `completeSet` (no new SetRowView callback). Behavior is identical.
- **D2 — Haptics injected as a closure.** `WorkoutSessionViewModel` gets `playBaselineRegainedHaptic: () -> Void` (default = double `UIImpactFeedbackGenerator(.medium)` 50ms apart) so tests can spy without UIKit.
- **D3 — Recommendation reaches the session VM via a settable property.** `WorkoutSessionScreen` builds its VM in `@State` with no args, so the screen takes `recommendation: TodayRecommendation = .normalDefault` and assigns `viewModel.recommendation` in `.task` before `start()` (same pattern as `updateWeightUnit`).
- **D4 — Restore path stays normal-mode.** `ActiveSessionSnapshot` is NOT extended with adjustments (no version bump). A restored comeback session keeps its adjusted row text but loses the feel picker / baseline haptic for that session. Derivation re-enters comeback on the next Today load. Acceptable for v1; spec does not require persistence.
- **D5 — Baseline row rendering.** Existing key `workout.last_session.baseline` is reps-only. New key `workout.last_session.baseline.format` ("Baseline: %@" / "ฐานเดิม: %@") wraps the same weight×reps body builders the `.last` branch uses, so "Baseline: 80 × 8, 8, 7" renders with weight. The old key stays for compatibility but the view stops using it.
- **D6 — Set-fetch budget on Today.** Engine is pure and takes pre-fetched sets. `TodayViewModel` only fetches sets when `NextBestSessionEngine.hasGapCandidate(history:now:)` is true, and only for post-gap sessions + the 10 most recent pre-gap sessions (baseline window). Normal days cost zero extra requests; overload hints therefore only decorate when sets were fetched (nil otherwise — allowed, suggestion is nullable).
- **D7 — `holdAddRep` affects weight only in prefill.** `ExerciseAdjustment` has no reps-target field (per spec struct); the "+1 rep" part surfaces in the Today ramp hint copy, not in set prefill.
- **D8 — Open-ended gap counts.** Step 1 of the derivation treats `now − lastCompleted ≥ 14d` as the most recent gap (gapEnd = now, zero post-gap sessions) — this is the primary acceptance path; the adjacent-pair walk covers gaps the user already returned from.

## Tasks

### Task 0 — Spec lock + sprint bookkeeping
- [x] Spec §2.1 decisions confirmed (already locked in spec).
- [x] Mark GYMTRACK.md §9 Sprint Tracking row 6 status `⏳` (in progress).

### Task 1 — Pure services + tests (no I/O)
Files: `Gymbros/Data/Services/SmartSessionAdvisor.swift`, `ComebackRampService.swift`,
`ProgressiveOverloadEngine.swift`, `HowDidThatFeel.swift`;
tests `GymbrosTests/SmartSessionAdvisorTests.swift`, `ComebackRampServiceTests.swift`,
`ProgressiveOverloadEngineTests.swift`.
- [x] `ComebackStage` + `SmartSessionAdvisor.stage(forDaysSinceLast:)` with bands 0–6 / 7–13 normal, 14–20 → (0.90, −1), 21–41 → (0.80, −1), 42+ → (0.60, −1); negative days clamp to 0. Band keys `comeback.band.normal|14_20|21_41|42_plus`.
- [x] `RampDecision` + `ComebackRampService.decide(lastComebackRPE:currentWeight:baselineWeight:)` per spec §4.3 (exit > nil-RPE hold > <6.5 +15 > <7.5 +10 > <8.5 hold > −5; missing baseline never exits, never crashes).
- [x] `HowDidThatFeel` enum (easy 6.0 / justRight 7.5 / hard 9.0 + `symbolName`).
- [x] `ProgressiveOverloadEngine.nextWeightSuggestion(forExerciseId:recentSessions:sets:)` per spec §4.4 (≥2 completed sessions in last 60 days; top-set RPE gates; +2.5 kg / hold / nil).
- [x] Tests per spec §10 lists (band boundaries 13→14, 41→42; all ramp branches; overload confidence gates).

### Task 2 — NextBestSessionEngine + tests
Files: `Gymbros/Data/Services/NextBestSessionEngine.swift`,
`GymbrosTests/NextBestSessionEngineTests.swift`.
- [x] `ExerciseAdjustment` struct per spec §2.1 #4.
- [x] `TodayRecommendation` (`mode: .normal | .comeback(stage:adjustments:)`, `programDay`, `reasonKey`, `gapDays`; `static let normalDefault`).
- [x] `recommend(program:history:sets:now:)` implementing the persistent state machine (spec §4.1 steps 1–7): most-recent unresolved gap (incl. open-ended gap per D8), gap-sized stage band, per-exercise baseline/current from sets keyed by `programExerciseId`, resolved = `current ≥ baseline && lastPostGapRPE ≤ 7.5`, bounded exit at `postGapSessions ≥ 4`, ramp targets via `ComebackRampService` (first post-gap session = `baseline × multiplier`), untracked/resolved exercises get multiplier 1.0 + full sets, `adjustedSets = max(targetSets + setDelta, 1)`.
- [x] `rampPreview` map + `overloadHints` map for normal mode, exposed for TodayData.
- [x] `static func hasGapCandidate(history:now:)` (D6 cheap pre-check).
- [x] Tests per spec §10 NextBestSessionEngine list, including persistence-across-sessions, most-recent-gap selection, per-exercise ramp vs global mode, weight-based exit, bounded exit.

### Task 3 — Analytics seam
Files: `Gymbros/Data/Services/Analytics/AnalyticsTracking.swift`.
- [x] `AnalyticsEvent` (4 cases), `AnalyticsTracking` protocol, `NoopAnalytics`, `#if DEBUG DebugConsoleAnalytics` (os_log), `AnalyticsProvider.makeDefault()` (Debug → console, Release → noop).

### Task 4 — Repository: updateSets(ids:rpe:)
Files: `Gymbros/Data/Repository/WorkoutRepository.swift`,
`GymbrosTests/WorkoutRepositoryPayloadTests.swift`, fake repos in
`WorkoutSessionViewModelTests.swift`, `TodayViewModelTests.swift`, `HistoryViewModelTests.swift` (any `WorkoutRepositoryProviding` conformance).
- [x] Protocol + impl: empty `ids` no-op; single PATCH `workout_sets` `.in("id", values:)` body `WorkoutSetRPEPayload(rpe:)`, `returning: .minimal`, `ErrorMapper` mapping.
- [x] Payload test `updateSetsRPEPayload` (encodes `{"rpe": 7.5}` only).
- [x] All test fakes conform (record calls for VM assertions).

### Task 5 — TodayViewModel + TodayData
Files: `Gymbros/Presentation/Today/TodayViewModel.swift`, `GymbrosTests/TodayViewModelTests.swift`.
- [x] Inject `engine` + `analytics` (defaults: real engine, `AnalyticsProvider.makeDefault()`).
- [x] `TodayData` gains `recommendation: TodayRecommendation` + `rampPreview: [UUID: RampDecision]`.
- [x] `fetch()` runs gap pre-check, fetches budgeted sets (D6), calls `engine.recommend`, keeps existing streak/welcome-back fields.
- [x] `trackComebackCardShown()` passthrough for the view (fires `.comebackCardShown`).
- [x] Tests: 15-day-old history → `.comeback` 14_20 band 0.90 multiplier; analytics spy fires exactly once per appearance.

### Task 6 — WorkoutSessionViewModel comeback support
Files: `Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift`,
`GymbrosTests/WorkoutSessionViewModelTests.swift`.
- [x] `var recommendation: TodayRecommendation = .normalDefault` (+ adjustments/baselines accessors, `mode.isComeback`).
- [x] `start()`: adjusted set counts (`adjustedSets`), set-1 weight chain `adjustedTargetWeight ?? targetWeight ?? lastLogged ?? blank`, `.comebackSessionStarted` when comeback.
- [x] Baseline reference rows: comeback exercises with baseline data get `LastSessionReference(label: .baseline, …)` overriding the `.last` lookup.
- [x] `applyFeedback(_:to:)` → completed-set IDs → `updateSets(ids:rpe:)` → patch in-memory RPEs; errors → `transientError` (skip `.cancelled`).
- [x] `checkBaselineRegained` inside `completeSet` (D1): kg-normalized weight ≥ baseline && reps ≥ baseline first-reps && comeback && not yet fired → double haptic (D2) + `.comebackExitBaselineReached` + `baselineRegainedThisSession = true`.
- [x] `finishSession()` success → `.comebackSessionFinished` when comeback.
- [x] Tests: comeback start defaults, applyFeedback repo call + RPE patch, baseline-regained idempotence, finish event (analytics spy + haptic spy + fake repo recording).

### Task 7 — UI components + wiring
Files: `Gymbros/Presentation/Today/Components/ComebackCardView.swift`,
`Gymbros/Presentation/Workout/Components/EasingBackBadge.swift`,
`Gymbros/Presentation/Workout/Components/HowDidThatFeelPicker.swift`,
`TodayView.swift`, `WorkoutSessionScreen.swift`, `WorkoutSessionView.swift`,
`WorkoutExercisePageView.swift`.
- [x] `ComebackCardView` per spec §7.1: bilingual TH+EN greeting, reason line (`reasonKey` + `gapDays`), ramp hint line when a ramp preview exists, Start CTA ≥48pt, semantic colors only, previews.
- [x] `TodayView`: comeback mode replaces the standard next-workout card with `ComebackCardView`; `.onAppear` fires `.comebackCardShown` once (`@State didLogCardShown`); Start passes recommendation into `WorkoutSessionScreen` (D3).
- [x] `EasingBackBadge` per spec §7.2 (capsule, `arrow.uturn.backward`, tertiarySystemFill).
- [x] `HowDidThatFeelPicker` per spec §7.3 (sheet, medium detent, 3 feel buttons ≥48pt + Skip; dismiss == Skip).
- [x] `WorkoutSessionScreen`: `recommendation` param; intercepts `onFinishExercise` in comeback mode → presents picker → select = `applyFeedback` then `finishExercise`; skip/dismiss = `finishExercise` only.
- [x] `WorkoutExercisePageView`: `isComebackMode` + `overloadHint` params; EasingBackBadge above set list; baseline row format (D5); muted "Try X" hint in normal mode only.
- [x] `WorkoutSessionView`: pass-throughs for badge/hint params.

### Task 8 — Localization
Files: `Gymbros/Resources/Localizable.xcstrings`.
- [x] All spec §8 keys (en + th): `today.comeback.*`, `comeback.reason.*`, `workout.comeback.*`, `workout.overload.hint`, `accessibility.today.comeback_card`, `accessibility.workout.easing_back`.
- [x] Additional keys from wiring: `workout.last_session.baseline.format` (D5), `today.comeback.ramp.increase|hold|decrease` (D7 hint line).
- [x] `jq empty Gymbros/Resources/Localizable.xcstrings` passes.

### Task 9 — Verify + close out
- [x] `git diff --check` — clean
- [x] Focused tests — all pass (SmartSessionAdvisor, ComebackRamp, ProgressiveOverload, NextBestSession, WorkoutRepositoryPayload, TodayViewModel, WorkoutSessionViewModel)
- [x] Full suite — `** TEST SUCCEEDED **`
- [x] Build — `** BUILD SUCCEEDED **`
- [ ] Manual smoke per spec §10 (needs Supabase `ended_at` edit — user-driven).
- [x] Update GYMTRACK.md row 6 → `✅` pending manual smoke note; update STANDUP.md.
- [ ] Commit.

## Out of scope (per spec)
StallDetector/DeloadAdvisor, TelemetryDeck, schema changes, `ProgramExercise.targetWeight`
mutation, cross-session weight pre-fill, app-wide bilingual copy. Stretch items
(BaselineRegainedToast, normal-card ramp chip, analytics coverage assertion) only if time permits.
