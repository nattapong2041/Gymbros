# Sprint 3 - Logger + Timer Implementation Plan

> **For agentic workers:** Read `CLAUDE.md`, `.agents/skills/gymbros-parallel-sprint/SKILL.md`, `.claude/GYMTRACK.md`, this sprint's `spec.md`, and this `CURRENT STATUS` block before starting. Mark each checkbox `[x]` immediately after completing it. Preserve unrelated user changes.

**Goal:** Build reliable workout logging with rest timer and crash/relaunch recovery.

---

## CURRENT STATUS

**Status:** Tasks 0–3 complete (commit `754efff`). Spec realigned 2026-05-11 to a paged one-exercise-at-a-time flow with per-exercise finish, free-swipe between unfinished pages, and a new `program_exercises.target_weight` column. **Realignment Fix-up F1 and F3 are complete; F2 remains in progress/pending, and F4–F6 remain pending before Task 4 (Wire + Verify).**

**Done:**
- Sprint 3 spec created at `.claude/sprints/S03-logger-timer/spec.md` and realigned 2026-05-11.
- Sprint 3 plan created at `.claude/sprints/S03-logger-timer/plan.md` (this file).
- Plan uses the no-protocol parallel strategy: spec + plan are the contract.
- Task 0 spec lock completed: ViewModel/state shapes, repository contract, localization key families, and ownership boundaries are confirmed.
- Task 1 implemented `WorkoutRepositoryProviding`, repository session/set methods, `WorkoutSessionViewModel`, `WorkoutSessionState`, `ActiveSessionBackupStore`, and focused Swift Testing coverage.
- Task 2 implemented `WorkoutSessionView`, `SetRowView`, `RestTimerRingView`, and `WorkoutSessionMockData` with full preview coverage.
- Task 3 implemented `Localizable.xcstrings` keys for workout logger, timer, restore, sync, and accessibility in English and Thai.
- UI components follow HIG with 48pt tap targets and semantic colors.
- Build verified on `iPhone 17e`.
- F1 added nullable `program_exercises.target_weight` locally and remotely on Supabase dev project `mkeoidoakzmsgjslihvf`, plus optional target-weight model/repository/program-builder UI support.
- F3 refactored workout state, backup snapshots, default-weight resolution, set carry-forward, per-exercise finish, and targeted tests for the paged workout flow.

**Last commit SHA:** 754efff

**Realignment 2026-05-11 — deltas to apply before Task 4 wiring:**
- Add nullable `program_exercises.target_weight` (schema + Swift model + builder UI).
- Refactor `WorkoutSessionView` from sectioned scroll to paged `TabView`, one exercise per page; extract `WorkoutExercisePageView`.
- Extend `WorkoutSessionData` / `WorkoutExerciseSection` / `ActiveSessionSnapshot` with `currentExerciseIndex`, `isFinished`, `finishedAt`, `defaultWeight`, `finishedExerciseIds`.
- Add `finishExercise(programExerciseId:)` and `goToExercise(index:)` to `WorkoutSessionViewModel`.
- Implement default-weight resolution (`targetWeight` → last-logged → blank) and previous-set actual carry-over.
- Retire `Color.gymAccentText`; audit all custom-color usage; ensure `AccentColor` and `GymPurple` color assets each have light + dark variants.
- Add new localization keys for exercise finish/finished/next, target weight, and progress count/done.
- Set completion must **not** auto-advance the TabView; only `finishExercise` does.

**Known deviations / constraints:**
- Use simulator `iPhone 17e` in all `xcodebuild` commands.
- Module name is `Gymbros`.
- Tests use Swift Testing, not XCTest.
- Xcode 16 auto-discovers files under `Gymbros/`; do not edit `project.pbxproj` just to add files.
- Do not manually declare `Color.gymPurple`; it is generated from the asset catalog.
- One schema change in Sprint 3: `program_exercises.target_weight` (nullable). Requires explicit user approval before applying remotely (`CLAUDE.md` Data Safety rule).
- Do not add HealthKit, Today, History, tabs, Smart Comeback, substitutions, offline-first sync, or formal superset grouping in Sprint 3.
- Use concrete `@Observable` ViewModels. Do not create ViewModel protocols unless explicitly requested later.
- If `xcodebuild` cannot write SwiftPM/Xcode/Simulator caches in the sandbox, rerun with the required approval.
- Task 1 does not wire runtime navigation or SwiftUI views; Task 4 owns that after the Realignment Fix-up section is complete.
- F3 targeted `xcodebuild test` was attempted with sandbox escalation but is currently blocked by unrelated top-level syntax errors in `Gymbros/Presentation/Programs/ExercisePickerView.swift` and `Gymbros/Presentation/Programs/ProgramDetailView.swift`. F3-owned files pass `swiftc -parse` and `git diff --check`.

**Next step:** Finish Realignment Fix-up F2 (color audit), then F4, F5, and F6 sequentially, then proceed to Task 4 (Wire + Verify).

---

## Parallel Execution Map

Task 0 is sequential and locks the shared shape.

After Task 0 is complete, these can run in parallel:

- **Task 1 - Workout Repo + ViewModel:** owns data, backup, concrete ViewModel, and tests.
- **Task 2 - Logger Views + Mock Data:** owns SwiftUI logger UI, custom components, preview/mock data.
- **Task 3 - Localization:** owns `Localizable.xcstrings`.

Task 4 is sequential integration after Tasks 1-3 are complete or explicitly handed off.

---

## Task 0: Spec Lock And Shared Shapes

**Owner:** Sequential first worker.

**Parallel-safe ownership:** Documentation and minimal shared helper shape only. Do not implement repositories, ViewModels, or SwiftUI screens in this task unless the plan is intentionally updated.

**Files likely touched:**
- `.claude/sprints/S03-logger-timer/spec.md`
- `.claude/sprints/S03-logger-timer/plan.md`

**Forbidden files:**
- `Gymbros/Data/Repository/WorkoutRepository.swift`
- `Gymbros/Presentation/Workout/*`
- `Gymbros/Resources/Localizable.xcstrings`

- [x] Confirm the spec names the concrete `WorkoutSessionViewModel` public state and actions clearly enough for Task 1 and Task 2 to work independently.
- [x] Confirm the spec defines `WorkoutSessionData`, `WorkoutExerciseSection`, `WorkoutSetRowState`, `RestTimerState`, and `ActiveSessionSnapshot` behavior.
- [x] Confirm localization key families are listed for Task 3.
- [x] Confirm Task 1, Task 2, Task 3, and Task 4 ownership boundaries are clear.
- [x] Update `CURRENT STATUS` with any spec-lock changes and the next parallel tasks.

**Verification:** Documentation review only.

**Handoff notes:** Locked no-protocol implementation with a concrete `@Observable WorkoutSessionViewModel`. Task 1 owns `WorkoutSessionData`, `WorkoutExerciseSection`, `WorkoutSetRowState`, `RestTimerState`, `WorkoutSetSyncState`, `ActiveSessionSnapshot`, repository protocol/test seams, backup store, and ViewModel tests. Task 2 owns workout views, mock data, previews, and accessibility labels using the same state names. Task 3 owns all `workout.*`, `workout.restore.*`, `workout.set.*`, `workout.timer.*`, `workout.finish.*`, `workout.sync.*`, and `accessibility.workout.*` keys in Thai and English. Task 4 owns `DayBuilderView` runtime wiring, restore gating, mock-path cleanup, and final verification.

---

## Task 1: Workout Repo + ViewModel

**Owner:** Data/ViewModel worker.

**Parallel-safe ownership:** Own repositories, payloads, backup store, concrete ViewModel, and focused tests. Do not edit SwiftUI view files except unavoidable compile fixes after noting them here.

**Files likely touched:**
- `Gymbros/Data/Repository/WorkoutRepository.swift`
- `Gymbros/Data/Repository/ActiveSessionBackupRepository.swift`
- `Gymbros/Data/Local/ActiveSessionBackupStore.swift`
- `Gymbros/Data/Local/ActiveSessionBackupModels.swift`
- `Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift`
- `Gymbros/Presentation/Workout/WorkoutSessionState.swift`
- `GymbrosTests/WorkoutSessionViewModelTests.swift`
- `GymbrosTests/ActiveSessionBackupTests.swift`

**Forbidden files:**
- `Gymbros/Presentation/Workout/WorkoutSessionView.swift`
- `Gymbros/Presentation/Workout/SetRowView.swift`
- `Gymbros/Presentation/Workout/RestTimerRingView.swift`
- `Gymbros/Resources/Localizable.xcstrings`
- `Gymbros/App/RootView.swift`
- `Gymbros/Presentation/Programs/*View.swift`

- [x] Add `WorkoutRepositoryProviding` if needed for tests.
- [x] Add `createSession(programDayId:startedAt:)` using an insert payload.
- [x] Change or overload set upload so completed uploads can return the inserted `WorkoutSet`.
- [x] Add `updateSet(_:)` if uploaded set editing is supported in Sprint 3.
- [x] Add `deleteSet(id:)`.
- [x] Keep `completeSession(_:endedAt:)` mapped through `ErrorMapper`.
- [x] Add `ActiveSessionSnapshot` with versioned Codable shape.
- [x] Add `ActiveSessionBackupStore` using `UserDefaults` JSON.
- [x] Add `ActiveSessionBackupRepository` so the ViewModel depends on a repository, not local storage.
- [x] Add concrete `WorkoutSessionViewModel` with `@Observable`.
- [x] Implement start session flow from `programDayId`.
- [x] Implement restore and discard restore flows.
- [x] Implement draft updates, set validation, complete set upload, retry upload, add set, delete set, rest timer state, and finish session.
- [x] Ensure backup is saved after every meaningful local mutation.
- [x] Ensure finish does not clear backup if upload or completion fails.
- [x] Ensure finish clears backup only after remote completion succeeds.
- [x] Add tests for backup encode/decode and version mismatch.
- [x] Add tests for set validation, add-set copy behavior, delete renumbering, upload failure retry, and finish backup behavior.
- [x] Run targeted tests for workout session and backup logic.
- [x] Update `CURRENT STATUS` and handoff notes with real initializer/action names and any intentional deviations.

**Verification command:**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/WorkoutSessionViewModelTests -only-testing:GymbrosTests/ActiveSessionBackupTests
```

**Handoff notes:** Implemented `WorkoutSessionViewModel(workoutRepository:programRepository:exerciseRepository:backupRepository:now:)` with public state/actions matching the spec: `state`, `transientError`, `activeTimer`, `isFinishing`, `pendingRestore`, `checkForRestore`, `start`, `restore`, `discardRestore`, `updateDraft`, `completeSet`, `retryUpload`, `addSet`, `deleteSet`, `startRestTimer`, `stopRestTimer`, and `finishSession`. Shared UI-facing data lives in `WorkoutSessionState.swift`: `WorkoutSessionData`, `WorkoutExerciseSection`, `WorkoutSetRowState`, and `WorkoutSetSyncState`. Backup persistence is layered as `ActiveSessionBackupStore` plus `ActiveSessionBackupModels` in `Data/Local`, then `ActiveSessionBackupRepository` in `Data/Repository`; the ViewModel maps between `ActiveSessionSetSnapshot` and `WorkoutSetRowState`. Repository upload currently uses row IDs as remote `workout_sets.id`; deleting an uploaded row calls `deleteSet(id:)`. Targeted tests passed with `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/WorkoutSessionViewModelTests -only-testing:GymbrosTests/ActiveSessionBackupTests`.

---

## Task 2: Logger Views + Mock Data

**Owner:** UI worker.

**Parallel-safe ownership:** Own SwiftUI logger views, custom components, previews, and mock data. Do not wire runtime navigation to the real ViewModel.

**Files likely touched:**
- `Gymbros/Presentation/Workout/WorkoutSessionView.swift`
- `Gymbros/Presentation/Workout/SetRowView.swift`
- `Gymbros/Presentation/Workout/RestTimerRingView.swift`
- `Gymbros/Presentation/Workout/WorkoutSessionMockData.swift`

**Forbidden files:**
- `Gymbros/Data/Repository/WorkoutRepository.swift`
- `Gymbros/Data/Repository/ActiveSessionBackupRepository.swift`
- `Gymbros/Data/Local/ActiveSessionBackupStore.swift`
- `Gymbros/Data/Local/ActiveSessionBackupModels.swift`
- `Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift`
- `Gymbros/Resources/Localizable.xcstrings`
- `Gymbros/App/RootView.swift`
- `Gymbros/Presentation/Programs/*View.swift`

- [x] Build `WorkoutSessionView` success layout with day title, exercise sections, set rows, Add Set actions, rest timer, and Finish Workout action.
- [x] Build loading state.
- [x] Build empty state for a day with no exercises.
- [x] Build error state with localized retry action.
- [x] Build restore prompt UI with Restore and Discard actions.
- [x] Build `SetRowView` with set number, weight input, reps input, RPE input, completion control, sync state, retry action, and delete support.
- [x] Build `RestTimerRingView` with ring, remaining time, and stop/skip action.
- [x] Ensure 48pt minimum tap targets for primary controls.
- [x] Add accessibility labels for icon-only buttons.
- [x] Add previews for loading, empty, error, restore, normal success, upload failed, and active timer states.
- [x] Use only mock/sample data and existing models; do not depend on Task 1 wiring.
- [x] Search for hardcoded user-facing strings in the new workout views and replace them with localization keys.
- [x] Run a build or preview-compatible compile check.
- [x] Update `CURRENT STATUS` and handoff notes with view initializer expectations and mock-only paths to remove or bypass.

**Verification command:**

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

**Handoff notes:** Task 2 implemented `WorkoutSessionMockData.swift`, `SetRowView.swift`, `RestTimerRingView.swift`, and `WorkoutSessionView.swift`. Previews are available for all states. UI uses localization keys like `workout.*`, `workout.set.*`, and `workout.timer.*` (to be defined in Task 3). `WorkoutSessionView` is designed to be wired to `WorkoutSessionViewModel` in Task 4; it currently accepts a `ViewState<WorkoutSessionData>` and various closures for actions. Build succeeded on `iPhone 17e`.

---

## Task 3: Localization

**Owner:** Localization worker.

**Parallel-safe ownership:** Own `Localizable.xcstrings`. Coordinate key names from the spec and Task 2 handoff if available.

**Files likely touched:**
- `Gymbros/Resources/Localizable.xcstrings`

**Forbidden files:**
- `Gymbros/Data/Repository/WorkoutRepository.swift`
- `Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift`
- `Gymbros/Presentation/Workout/WorkoutSessionView.swift`
- `Gymbros/Presentation/Workout/SetRowView.swift`
- `Gymbros/Presentation/Workout/RestTimerRingView.swift`

- [x] Add `workout.*` keys for screen title, loading, empty, retry, start, finish, finishing, and validation.
- [x] Add `workout.restore.*` keys for restore prompt, restore action, discard action, and corrupt backup copy.
- [x] Add `workout.set.*` keys for set number, weight, reps, RPE, complete, add set, delete set, and validation.
- [x] Add `workout.timer.*` keys for rest, remaining time, complete, stop, and skip.
- [x] Add `workout.sync.*` keys for pending, uploading, uploaded, failed, and retry.
- [x] Add `accessibility.workout.*` keys for icon-only logger buttons.
- [x] Verify every new key has English and Thai values.
- [x] Search new workout view files for hardcoded user-facing strings if Task 2 is available.
- [x] Update `CURRENT STATUS` and handoff notes with key families added and any missing copy.

**Verification:** Inspect string catalog and run a hardcoded string search after Task 2 exists.

**Handoff notes:** Task 3 added all required workout localization keys to `Localizable.xcstrings`. Key families cover the main workout view, restore prompts, set row inputs/actions, rest timer controls, and sync status indicators. Accessibility labels for icon-only buttons (timer stop/skip, set completion) are also included. All keys have complete English and Thai translations.

---

## Realignment Fix-up (2026-05-11)

These tasks bring the existing Sprint 3 code in line with the realigned spec (paged TabView, per-exercise finish, free swipe, `target_weight`, color rules) before Task 4 wiring starts. Tasks 0–3 above stay as-is for handoff history; their outputs are amended, not discarded.

Execution order:

```
F1 ─┐
    ├─ F2  (parallel)
    └─ F3  (parallel, depends on F1)
F4 (depends on F3)
F5 (after F4 so it can grep the refactored views)
F6 (final verification before Task 4)
```

---

### F1 — Schema + ProgramExercise.targetWeight

**Owner:** Data worker. Sequential. Blocks F3 and Task 4.

**Files likely touched:**
- `supabase/schema.sql`
- `supabase/migrations/2026-05-11_program_exercises_target_weight.sql` (new)
- `Gymbros/Model/ProgramExercise.swift`
- `Gymbros/Presentation/Programs/ProgramExerciseForm.swift`
- `Gymbros/Presentation/Programs/ProgramExerciseEditorView.swift`
- `Gymbros/Data/Repository/ProgramRepository.swift`
- `Gymbros/Resources/Localizable.xcstrings` (one key: `program.exercise.target_weight`)

**Forbidden files:**
- `Gymbros/Presentation/Workout/*` (F3/F4 territory)
- `Gymbros/Core/AppTheme.swift` (F2 territory)

- [x] Add `target_weight numeric null` to `program_exercises` in `supabase/schema.sql`.
- [x] Create `supabase/migrations/2026-05-11_program_exercises_target_weight.sql` with the same change as an idempotent migration.
- [x] **Pause and request user approval before applying remotely** (`CLAUDE.md` Data Safety rule).
- [x] Add `var targetWeight: Double?` to `ProgramExercise` with `CodingKeys.targetWeight = "target_weight"`.
- [x] Add a target-weight text field to `ProgramExerciseForm` (numeric ≥ 0 when present; empty = nil). Add a `ProgramFormValidation.validateTargetWeight` helper.
- [x] Wire the field into `ProgramExerciseEditorView` between rest seconds and notes. Use the `program.exercise.target_weight` localization key.
- [x] Update `ProgramRepository` insert/update payloads to include `target_weight`.
- [x] Update existing `ProgramExercise` tests/fixtures if any rely on a specific field set.

**Verification command:**

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

**Handoff notes:** Complete. Target weight is optional end-to-end: empty text saves as `nil`, numeric values `>= 0` persist, and invalid/negative input is rejected. Remote Supabase dev project `mkeoidoakzmsgjslihvf` was migrated with `program_exercises_target_weight`; verification query returned `target_weight` as nullable `numeric`. Targeted tests passed for `ProgramRepositoryPayloadTests`, `ProgramBuilderValidationTests`, and `ProgramViewModelTests`; F1 build passed on `iPhone 17e`. Supabase advisors after DDL reported existing auth leaked password protection warning and pre-existing performance lint items; no new target-weight-specific security issue was reported.

---

### F2 — Color audit and `gymAccentText` retirement

**Owner:** UI worker. Parallel with F3.

**Files likely touched:**
- `Gymbros/Core/AppTheme.swift`
- `Gymbros/Presentation/Workout/WorkoutSessionView.swift` (or wherever `gymAccentText` is referenced post-F4)
- `Gymbros/Assets.xcassets/AccentColor.colorset/Contents.json`
- `Gymbros/Assets.xcassets/GymPurple.colorset/Contents.json`

**Forbidden files:**
- `Gymbros/Model/*`
- `Gymbros/Data/*`
- `Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift` (F3)

- [ ] Remove `Color.gymAccentText` from `AppTheme.swift`. Keep only `gymAccent` and `gymPurple` (auto-generated from assets) plus any pure SwiftUI semantic aliases that are clearly useful (`gymSurface`/`gymBackground` may be kept as semantic-color aliases or removed for clarity).
- [ ] Replace `Color.gymAccentText` callers with `Color.gymAccent` (text on `Color.gymAccent` background) or `.primary`/`.secondary` (text on system background). Verify both light and dark mode visually.
- [ ] Verify `AccentColor.colorset/Contents.json` and `GymPurple.colorset/Contents.json` each contain both a Universal/Any appearance and a Dark appearance. Add a Dark variant if missing (target: same hue, tuned for contrast on dark backgrounds).
- [ ] Grep for forbidden color forms:
  ```bash
  rg -n "Color\(red:|#[0-9A-Fa-f]{6}|gymAccentText|Color\(\"[A-Z]" Gymbros/ --type swift
  ```
  Expect zero hits outside `AppTheme.swift` declarations of `gymAccent` / `gymPurple`. Re-run after F4 since the workout views will be rewritten.

**Verification command:**

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

**Handoff notes:** Add when complete.

---

### F3 — ViewModel + state refactor

**Owner:** Data/ViewModel worker. Parallel with F2. Depends on F1 (needs `ProgramExercise.targetWeight`).

**Files likely touched:**
- `Gymbros/Presentation/Workout/WorkoutSessionState.swift`
- `Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift`
- `Gymbros/Data/Local/ActiveSessionBackupModels.swift`
- `Gymbros/Data/Local/ActiveSessionBackupStore.swift` (version bump)
- `Gymbros/Data/Repository/ActiveSessionBackupRepository.swift` (if signature changes)
- `Gymbros/Data/Repository/WorkoutRepository.swift` (may add `fetchLastLoggedSet`)
- `GymbrosTests/WorkoutSessionViewModelTests.swift`
- `GymbrosTests/ActiveSessionBackupTests.swift`

**Forbidden files:**
- `Gymbros/Presentation/Workout/WorkoutSessionView.swift` (F4)
- `Gymbros/Presentation/Workout/SetRowView.swift` (F4)
- `Gymbros/Presentation/Workout/RestTimerRingView.swift` (F4)
- `Gymbros/Resources/Localizable.xcstrings` (F5)

- [x] Extend `WorkoutSessionData` with `currentExerciseIndex: Int`.
- [x] Extend `WorkoutExerciseSection` with `isFinished: Bool`, `finishedAt: Date?`, `defaultWeight: Double?`.
- [x] Extend `ActiveSessionSnapshot` with `finishedExerciseIds: [UUID]` and `currentExerciseIndex: Int`. Bump the snapshot `version` constant.
- [x] Add `finishExercise(programExerciseId:)` and `goToExercise(index:)` to `WorkoutSessionViewModel`.
- [x] In `start(programDayId:)`, resolve `defaultWeight` per exercise: `programExercise.targetWeight` → last-logged history → nil. Pre-fill set 1 weight from `defaultWeight` when present.
- [x] If needed, add `WorkoutRepository.fetchLastLoggedSet(exerciseId:before:)` mapped through `ErrorMapper`.
- [x] In `completeSet`, after enqueuing the upload, if a next set row exists in the same exercise and its `weightText`/`repsText` are still the row's initial values (blank or default), copy the just-completed actual `weightText` and `repsText` into it. Do not copy RPE.
- [x] Implement `finishExercise`: require at least one `.uploaded` set in the section, set `isFinished = true` and `finishedAt = now`, save backup, then set `currentExerciseIndex` to the next index where `!isFinished` (or leave it on the just-finished page if none).
- [x] Set completion must **not** change `currentExerciseIndex`.
- [x] On restore, recompute `currentExerciseIndex` to the first `!isFinished` section regardless of the snapshot value; do not show any per-exercise resume prompt.
- [x] Update existing `WorkoutSessionViewModelTests` and `ActiveSessionBackupTests` for the new state shape.
- [x] Add three new tests:
  - `finishExercise` advances `currentExerciseIndex` to the next unfinished section.
  - Restore recomputes `currentExerciseIndex` to the first unfinished section.
  - Completing set N copies actual weight/reps to set N+1 in the same exercise.

**Verification command:**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/WorkoutSessionViewModelTests -only-testing:GymbrosTests/ActiveSessionBackupTests
```

**Handoff notes:** F3 is implemented in the data/ViewModel/test layer. `WorkoutSessionData` now stores `currentExerciseIndex`; `WorkoutExerciseSection` stores finish state, `finishedAt`, and `defaultWeight`; `ActiveSessionSnapshot.currentVersion` is `2` and persists `finishedExerciseIds`, `currentExerciseIndex`, and `defaultWeights`. `WorkoutSessionViewModel` now exposes `goToExercise(index:)` and `finishExercise(programExerciseId:)`, starts set 1 from target/last-logged default weight, leaves later sets blank until previous actuals are carried forward, does not auto-advance on set completion, requires all sections to be finished before session finish, and restores to the first unfinished section. `WorkoutRepositoryProviding.fetchLastLoggedSet(exerciseId:before:)` is implemented against `workout_sets` with `completed_at < before`, descending order, and `limit(1)`.

Targeted tests were expanded for target-weight defaults, last-logged fallback, lookup failure fallback, carry-forward without RPE, no auto-advance on set completion, finish exercise gating/advance, restore index recompute, and backup round trip fields. Verification attempted:

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/WorkoutSessionViewModelTests -only-testing:GymbrosTests/ActiveSessionBackupTests
```

Result: blocked before F3 tests could run by unrelated top-level syntax errors in `Gymbros/Presentation/Programs/ExercisePickerView.swift` and `Gymbros/Presentation/Programs/ProgramDetailView.swift`. F3-owned files passed `swiftc -parse` and `git diff --check`.

---

### F4 — Logger view refactor to paged TabView

**Owner:** UI worker. Sequential after F3.

**Files likely touched:**
- `Gymbros/Presentation/Workout/WorkoutSessionView.swift`
- `Gymbros/Presentation/Workout/WorkoutExercisePageView.swift` (new)
- `Gymbros/Presentation/Workout/SetRowView.swift` (read-only mode)
- `Gymbros/Presentation/Workout/WorkoutSessionMockData.swift`

**Forbidden files:**
- `Gymbros/Data/*`
- `Gymbros/Model/*`
- `Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift`
- `Gymbros/Resources/Localizable.xcstrings` (F5)

- [ ] Replace the sectioned `ScrollView` in `WorkoutSessionView` with a `TabView { ... }.tabViewStyle(.page(indexDisplayMode: .never))` driven by `currentExerciseIndex`.
- [ ] Extract `WorkoutExercisePageView` taking one `WorkoutExerciseSection` and the same action closures as today. Layout: header (name, prescription, target weight), set list, Add Set, Finish Exercise.
- [ ] Add a custom progress header at the top of `WorkoutSessionView`: `Day name · X / N · K done`. Use `workout.progress.count` and `workout.progress.done` keys.
- [ ] When `section.isFinished == true`:
  - Disable all set row inputs.
  - Hide the sync indicator (all uploaded).
  - Replace Finish Exercise button with a non-interactive ✓ "Finished" badge using `Color.gymPurple`.
  - Do not show Add Set.
  - Do not show any resume prompt on this page.
- [ ] Finish Workout in the toolbar is disabled until every section is finished, in addition to the existing `isFinishing` rule.
- [ ] Update `WorkoutSessionMockData` to include: an in-progress page, a finished page, a mixed-state day, and a restore scenario.
- [ ] Refresh previews for: loading, empty, error, restore, normal success, finished page, mixed page, upload failed, active timer.
- [ ] Re-run the F2 color grep against the refactored workout views.

**Verification command:**

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

**Handoff notes:** Add when complete.

---

### F5 — Localization additions

**Owner:** Localization worker. Sequential after F4.

**Files likely touched:**
- `Gymbros/Resources/Localizable.xcstrings`

**Forbidden files:**
- Swift source files (already wired by F4).

- [ ] Add the following keys with complete Thai and English copy:
  - `workout.exercise.finish`
  - `workout.exercise.finished`
  - `workout.exercise.next`
  - `workout.exercise.target_weight`
  - `workout.progress.count` (format: `"%lld / %lld"`)
  - `workout.progress.done` (format: `"%lld done"`)
- [ ] Confirm `program.exercise.target_weight` is present (added by F1).
- [ ] Grep `Gymbros/Presentation/Workout/` and `Gymbros/Presentation/Programs/` for hardcoded user-facing strings and replace with keys.

**Verification:** Inspect string catalog; spot-check English and Thai for completeness.

**Handoff notes:** Add when complete.

---

### F6 — Realignment verification

**Owner:** Final integration worker. Sequential after F5. Blocks Task 4.

- [ ] Run the full test suite:
  ```bash
  xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'
  ```
- [ ] Re-run the color grep:
  ```bash
  rg -n "Color\(red:|#[0-9A-Fa-f]{6}|gymAccentText|Color\(\"[A-Z]" Gymbros/ --type swift
  ```
  Expect zero hits outside `AppTheme.swift` declarations.
- [ ] Light/dark mode visual sweep of `WorkoutSessionView`, `WorkoutExercisePageView`, `SetRowView`, `RestTimerRingView`, `ProgramExerciseEditorView`.
- [ ] Update `CURRENT STATUS` with results and the new last commit SHA (if user asks for a commit), then proceed to Task 4 (Wire + Verify).

**Handoff notes:** Add when complete.

---

## Task 4: Wiring, Integration, And Verification

**Owner:** Final integration worker.

**Start only after:** Tasks 1, 2, and 3 are complete or explicitly handed off.

**Files likely touched:**
- `Gymbros/App/RootView.swift`
- `Gymbros/Presentation/Programs/DayBuilderView.swift`
- `Gymbros/Presentation/Workout/*`
- `Gymbros/Resources/Localizable.xcstrings`
- tests as needed

**Forbidden files:**
- None within Sprint 3 scope, but preserve unrelated user changes and inspect diffs before editing.

- [ ] Review Task 1, Task 2, and Task 3 handoff notes.
- [ ] Connect `WorkoutSessionView` to concrete `WorkoutSessionViewModel`.
- [ ] Remove, isolate, or preview-scope mock-only runtime paths.
- [ ] Add temporary Start Workout entry from `DayBuilderView` when the day has exercises.
- [ ] Add restore prompt check for authenticated launch or workout entry.
- [ ] Ensure a user cannot start a second workout while a restore is pending.
- [ ] Resolve compile mismatches between ViewModel state/actions and view expectations.
- [ ] Confirm all user-facing strings use localization keys.
- [ ] Confirm all visible errors use localized `AppError` UI.
- [ ] Run targeted workout tests.
- [ ] Run full `xcodebuild test`.
- [ ] Manual smoke test: start workout, log sets, add/delete set, timer completes, relaunch restores, finish clears backup.
- [ ] Check `git diff` for accidental secrets or unrelated changes.
- [ ] Update `CURRENT STATUS`: mark Sprint 3 complete if verified, list test results, last commit SHA if committed, known deviations, and next step.

**Verification command:**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'
```

**Handoff notes:** Add final integration notes here.

---

## Acceptance Checklist

- [ ] A user can start a workout from an existing program day.
- [ ] A workout session row is created remotely.
- [ ] Set rows are editable for weight, reps, and optional RPE.
- [ ] Completed sets upload in the background.
- [ ] Failed set uploads can be retried.
- [ ] Add Set copies previous values for the same exercise.
- [ ] Delete Set removes an unneeded row and renumbers remaining rows.
- [ ] Rest timer appears after completing a set and haptic fires on completion.
- [ ] Relaunch with an unfinished workout offers Restore and Discard.
- [ ] Restore returns the user to the active workout state.
- [ ] Finish waits for uploads, completes the session remotely, and clears backup.
- [ ] Backup remains if finish fails.
- [ ] All visible strings are localized in Thai and English.
- [ ] No raw SDK/database errors reach SwiftUI.
- [ ] Automated tests pass.
- [ ] Manual smoke test passes on `iPhone 17e`.
