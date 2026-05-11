# Sprint 3 - Logger + Timer Implementation Plan

> **For agentic workers:** Read `CLAUDE.md`, `.agents/skills/gymbros-parallel-sprint/SKILL.md`, `.claude/GYMTRACK.md`, this sprint's `spec.md`, and this `CURRENT STATUS` block before starting. Mark each checkbox `[x]` immediately after completing it. Preserve unrelated user changes.

**Goal:** Build reliable workout logging with rest timer and crash/relaunch recovery.

---

## CURRENT STATUS

**Status:** Task 1 complete. Repository, shared workout state, data-local active-session backup, concrete ViewModel, and focused tests are implemented. Tasks 2 and 3 are ready to continue in parallel; Task 4 should wire the UI after those handoffs.

**Done:**
- Sprint 3 spec created at `.claude/sprints/S03-logger-timer/spec.md`.
- Sprint 3 plan created at `.claude/sprints/S03-logger-timer/plan.md`.
- Plan uses the no-protocol parallel strategy: spec + plan are the contract.
- Task 0 spec lock completed: ViewModel/state shapes, repository contract, localization key families, and ownership boundaries are confirmed.
- Task 1 implemented `WorkoutRepositoryProviding`, repository session/set methods, `WorkoutSessionViewModel`, `WorkoutSessionState`, `ActiveSessionBackupStore`, and focused Swift Testing coverage.
- Task 1 architecture cleanup moved `ActiveSessionBackupStore` from `Presentation/Workout` to `Data/Local`.

**Last commit SHA:** f0cb7e8

**Known deviations / constraints:**
- Use simulator `iPhone 17e` in all `xcodebuild` commands.
- Module name is `Gymbros`.
- Tests use Swift Testing, not XCTest.
- Xcode 16 auto-discovers files under `Gymbros/`; do not edit `project.pbxproj` just to add files.
- Do not manually declare `Color.gymPurple`; it is generated from the asset catalog.
- No schema migration is expected for Sprint 3.
- Do not add HealthKit, Today, History, tabs, Smart Comeback, substitutions, or offline-first sync in Sprint 3.
- Use concrete `@Observable` ViewModels. Do not create ViewModel protocols unless explicitly requested later.
- If `xcodebuild` cannot write SwiftPM/Xcode/Simulator caches in the sandbox, rerun with the required approval.
- Task 1 does not wire runtime navigation or SwiftUI views; Task 4 owns that after Task 2 and Task 3.

**Next step:** Dispatch/complete Tasks 2 and 3 in parallel, then run Task 4 wiring and verification.

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
- `Gymbros/Data/Local/ActiveSessionBackupStore.swift`
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

**Handoff notes:** Implemented `WorkoutSessionViewModel(workoutRepository:programRepository:exerciseRepository:backupStore:now:)` with public state/actions matching the spec: `state`, `transientError`, `activeTimer`, `isFinishing`, `pendingRestore`, `checkForRestore`, `start`, `restore`, `discardRestore`, `updateDraft`, `completeSet`, `retryUpload`, `addSet`, `deleteSet`, `startRestTimer`, `stopRestTimer`, and `finishSession`. Shared UI-facing data lives in `WorkoutSessionState.swift`: `WorkoutSessionData`, `WorkoutExerciseSection`, `WorkoutSetRowState`, `WorkoutSetSyncState`, `RestTimerState`, and `ActiveSessionSnapshot`. Backup persistence lives in `Gymbros/Data/Local/ActiveSessionBackupStore.swift`, uses `AppConstants.Storage.activeSessionKey`, and stores versioned JSON. Repository upload currently uses row IDs as remote `workout_sets.id`; deleting an uploaded row calls `deleteSet(id:)`. Targeted tests passed with `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/WorkoutSessionViewModelTests -only-testing:GymbrosTests/ActiveSessionBackupTests`.

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
- `Gymbros/Data/Local/ActiveSessionBackupStore.swift`
- `Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift`
- `Gymbros/Resources/Localizable.xcstrings`
- `Gymbros/App/RootView.swift`
- `Gymbros/Presentation/Programs/*View.swift`

- [ ] Build `WorkoutSessionView` success layout with day title, exercise sections, set rows, Add Set actions, rest timer, and Finish Workout action.
- [ ] Build loading state.
- [ ] Build empty state for a day with no exercises.
- [ ] Build error state with localized retry action.
- [ ] Build restore prompt UI with Restore and Discard actions.
- [ ] Build `SetRowView` with set number, weight input, reps input, RPE input, completion control, sync state, retry action, and delete support.
- [ ] Build `RestTimerRingView` with ring, remaining time, and stop/skip action.
- [ ] Ensure 48pt minimum tap targets for primary controls.
- [ ] Add accessibility labels for icon-only buttons.
- [ ] Add previews for loading, empty, error, restore, normal success, upload failed, and active timer states.
- [ ] Use only mock/sample data and existing models; do not depend on Task 1 wiring.
- [ ] Search for hardcoded user-facing strings in the new workout views and replace them with localization keys.
- [ ] Run a build or preview-compatible compile check.
- [ ] Update `CURRENT STATUS` and handoff notes with view initializer expectations and mock-only paths to remove or bypass.

**Verification command:**

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

**Handoff notes:** Add notes here before marking Task 2 complete.

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

- [ ] Add `workout.*` keys for screen title, loading, empty, retry, start, finish, finishing, and validation.
- [ ] Add `workout.restore.*` keys for restore prompt, restore action, discard action, and corrupt backup copy.
- [ ] Add `workout.set.*` keys for set number, weight, reps, RPE, complete, add set, delete set, and validation.
- [ ] Add `workout.timer.*` keys for rest, remaining time, complete, stop, and skip.
- [ ] Add `workout.sync.*` keys for pending, uploading, uploaded, failed, and retry.
- [ ] Add `accessibility.workout.*` keys for icon-only logger buttons.
- [ ] Verify every new key has English and Thai values.
- [ ] Search new workout view files for hardcoded user-facing strings if Task 2 is available.
- [ ] Update `CURRENT STATUS` and handoff notes with key families added and any missing copy.

**Verification:** Inspect string catalog and run a hardcoded string search after Task 2 exists.

**Handoff notes:** Add notes here before marking Task 3 complete.

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
