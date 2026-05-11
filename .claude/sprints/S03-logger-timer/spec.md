# Sprint 3 - Logger + Timer

> Detailed implementation spec for coding agents.
> Reference: `.claude/GYMTRACK.md` Section 9 - Phase 1, Sprint 3

---

## Overview

**Goal:** Let a signed-in user start a workout from an existing program day, log sets reliably, use a rest timer, finish the session, and restore an unfinished session after relaunch.

**Primary acceptance test:** Start a workout from a program day, log multiple sets with weight/reps/RPE, add and delete a set, see the rest timer after completing a set, force-relaunch the app, restore the active session, finish it, and confirm the backup is cleared.

**Effort estimate:** Complex.

**Dependencies:** Sprint 2 is complete: users can create programs, days, and program exercises. Sprint 1 already created `workout_sessions`, `workout_sets`, `WorkoutSession`, `WorkoutSet`, and `WorkoutRepository`.

---

## 1. Requirements

### Must Have

```text
✓ WorkoutSessionView for one program day
✓ Concrete WorkoutSessionViewModel using @Observable
✓ In-memory active session state while the app is running
✓ ActiveSessionBackup using Codable JSON in UserDefaults
✓ Crash/relaunch recovery prompt with Restore and Discard actions
✓ SetRowView with weight, reps, RPE, completion, and sync status
✓ Add set per exercise, copying the previous set values when available
✓ Swipe/delete an unneeded set
✓ Background async upload per completed set
✓ Retry failed set upload
✓ RestTimerRingView using target rest seconds from ProgramExercise
✓ Haptic when rest timer completes
✓ Finish session waits for pending uploads, marks session complete, and clears backup
✓ All visible strings localized in Thai and English
✓ All user-visible errors flow through AppError/ViewState
✓ App builds and tests pass on iPhone 17e simulator
```

### Out of Scope

```text
✗ HealthKit
✗ Today screen
✗ History screen
✗ Tab navigation
✗ Smart Comeback / Next Best Session Engine
✗ Progressive overload suggestions
✗ Exercise substitution / defer / skip flows
✗ True offline-first sync queue
✗ Database schema migrations
✗ Editing completed historical sessions
```

---

## 2. Existing Foundation To Reuse

Use the current files and conventions:

```text
Gymbros/Model/WorkoutSession.swift
Gymbros/Model/WorkoutSet.swift
Gymbros/Model/ProgramDay.swift
Gymbros/Model/ProgramExercise.swift
Gymbros/Model/Exercise.swift
Gymbros/Data/Repository/WorkoutRepository.swift
Gymbros/Data/Repository/ProgramRepository.swift
Gymbros/Data/Repository/ExerciseRepository.swift
Gymbros/Core/ErrorHandling/AppError.swift
Gymbros/Core/ErrorHandling/ViewState.swift
Gymbros/Resources/Localizable.xcstrings
```

Rules:

- Use concrete `@Observable` ViewModels, not ViewModel protocols.
- The spec and plan are the coordination contract between parallel agents.
- Keep models `Codable` with explicit `CodingKeys`.
- Do not add nested relationship properties to `CodingKeys`.
- Repository methods may be `async throws`, but anything thrown outside the data layer must be `AppError`.
- Do not expose raw Supabase errors, SQL details, status codes, or `localizedDescription` in SwiftUI.
- Do not add `Color.gymPurple` manually; Xcode auto-generates it from the named color asset.

---

## 2.1 Spec Lock Decisions

Task 0 locks these shared decisions before parallel work starts:

- Use a concrete `@Observable WorkoutSessionViewModel`; do not create a ViewModel protocol.
- Task 1 owns the shared workout state structs used by both the ViewModel and views.
- Active session backup persistence lives in `Gymbros/Data/Local/ActiveSessionBackupStore.swift`; UI-facing workout state stays in `Gymbros/Presentation/Workout/WorkoutSessionState.swift`.
- `WorkoutSetRowState.syncState` uses: `pending`, `uploading`, `uploaded`, `failed(AppError)`.
- `ActiveSessionSnapshot` is versioned Codable JSON in `UserDefaults`; it must not store secrets, tokens, or auth headers.
- Restore decode failure or version mismatch maps to `.decoding` and offers Discard only.
- All repository errors crossing into ViewModels must be `AppError`.
- Task 4 owns runtime wiring from `DayBuilderView` to `WorkoutSessionView`.

---

## 3. Product Flow

Sprint 4 will introduce Today navigation. Sprint 3 uses a temporary start path from the existing program/day flow:

```text
ProgramListView
→ ProgramDetailView
→ DayBuilderView
→ Start Workout
→ WorkoutSessionView
```

Rules:

- Show Start Workout only when the day has at least one exercise.
- Starting creates a `workout_sessions` row immediately.
- If an unfinished local backup exists, show Restore / Discard before allowing a new session.
- Restoring opens the saved session state.
- Discarding clears the local backup and may optionally delete the remote incomplete session if the repository supports it safely.

---

## 4. Workout State

### Expected ViewModel Shape

Task 1 implements a concrete ViewModel with this target shape. This is not a protocol.

```swift
@MainActor
@Observable
final class WorkoutSessionViewModel {
    var state: ViewState<WorkoutSessionData>
    var transientError: AppError?
    var activeTimer: RestTimerState?
    var isFinishing: Bool
    var pendingRestore: ActiveSessionSnapshot?

    func checkForRestore() async
    func start(programDayId: UUID) async
    func restore(_ snapshot: ActiveSessionSnapshot) async
    func discardRestore(_ snapshot: ActiveSessionSnapshot) async
    func updateDraft(setId: UUID, weightText: String, repsText: String, rpe: Double?) async
    func completeSet(setId: UUID) async
    func retryUpload(setId: UUID) async
    func addSet(after setId: UUID) async
    func deleteSet(setId: UUID) async
    func startRestTimer(seconds: Int, sourceSetId: UUID)
    func stopRestTimer()
    func finishSession() async
}
```

The implementer may adjust exact parameter names during wiring if the behavior remains the same.

### WorkoutSessionData

Use a shared data shape that can be created by the ViewModel and by UI previews:

```text
session: WorkoutSession
day: ProgramDay
exerciseSections: [WorkoutExerciseSection]
exerciseLookup: [UUID: Exercise]
startedAt: Date
```

`WorkoutExerciseSection`:

```text
programExercise: ProgramExercise
exercise: Exercise?
sets: [WorkoutSetRowState]
```

`WorkoutSetRowState`:

```text
id: UUID
exerciseId: UUID
programExerciseId: UUID?
setNumber: Int
weightText: String
repsText: String
rpe: Double?
targetRestSeconds: Int?
syncState: pending | uploading | uploaded | failed(AppError)
isCompleted: Bool
```

`RestTimerState`:

```text
sourceSetId: UUID
targetSeconds: Int
startedAt: Date
endsAt: Date
remainingSeconds: Int
isComplete: Bool
```

---

## 5. Data Behavior

### Starting A Session

- Fetch `ProgramDay` by id.
- Fetch its `ProgramExercise` rows and exercise metadata.
- Insert one `workout_sessions` row with `user_id`, `program_day_id`, and `started_at`.
- Create local draft rows for each exercise based on `target_sets`.
- Each exercise starts with `target_sets` editable rows.
- Initial weight is blank unless a previous value is available in local restored state.
- Initial reps may default to `target_reps_min`.

### Completing A Set

- Validate weight and reps before upload.
- Weight must be numeric and `>= 0`.
- Reps must be an integer in `1...100`.
- RPE is optional; if present it must be in `1.0...10.0`.
- On completion, save backup immediately.
- Upload the set in the background.
- Show sync state per row.
- Start rest timer using the row's `targetRestSeconds` when available.

### Add Set

- Add a new row under the same exercise.
- New row uses the next dense `setNumber`.
- Copy weight, reps, and RPE from the previous row for that exercise when available.
- Save backup after adding.

### Delete Set

- Allow deleting local uncompleted rows.
- If an uploaded row is deleted, delete the remote `workout_sets` row too if repository support is implemented in Task 1.
- Renumber remaining rows for that exercise densely from 1.
- Save backup after deleting.

### Finish Session

- Disable duplicate finish actions while finishing.
- Validate that at least one set has been completed and uploaded or is uploadable.
- Retry or wait for pending uploads before marking complete.
- Call repository `completeSession(sessionId:endedAt:)`.
- Clear local backup only after remote completion succeeds.
- Leave backup in place if completion fails.

---

## 6. Backup And Restore

Use `UserDefaults` with versioned Codable JSON.

`ActiveSessionSnapshot`:

```text
version: Int
session: WorkoutSession
day: ProgramDay
programExercises: [ProgramExercise]
exerciseLookup: [UUID: Exercise]
rowStates: [WorkoutSetRowState]
activeTimer: RestTimerState?
updatedAt: Date
```

Rules:

- Use a single key such as `activeWorkoutSessionBackup`.
- Decode failure maps to `.decoding`; offer Discard.
- Version mismatch offers Discard.
- Backup after every meaningful local mutation.
- Clear backup after successful finish or explicit discard.
- Do not store secrets or auth tokens in backup.

---

## 7. UI Requirements

### WorkoutSessionView

States:

- loading: progress indicator
- empty: no exercises in this day
- success: exercise sections with set rows and finish action
- error: localized retry UI
- restore prompt: Restore and Discard

Success layout:

- Navigation title uses the program day name.
- Each exercise section shows exercise name and target prescription.
- Each set row has editable weight, reps, optional RPE, completion checkbox/button, and sync status.
- Add Set action appears per exercise.
- Finish Workout action is prominent and disabled while finishing.

### SetRowView

Custom component required by `CLAUDE.md`.

Fields:

- set number
- weight input
- reps input
- RPE picker or menu
- completion control
- sync state icon/text

Rules:

- Minimum 48pt tap targets.
- Numeric inputs use numeric keyboards.
- Failed upload rows expose Retry.
- Do not show raw error text.

### RestTimerRingView

Custom component required by `CLAUDE.md`.

Behavior:

- Circular countdown ring.
- Shows remaining time.
- Stop/skip action.
- Light haptic when complete.
- Timer continues correctly when app returns from background by deriving remaining time from dates.

---

## 8. Repository Contract

Extend `WorkoutRepository` and add `WorkoutRepositoryProviding` for tests if useful.

Required behavior:

```swift
func createSession(programDayId: UUID, startedAt: Date) async throws -> WorkoutSession
func uploadSet(_ set: WorkoutSet) async throws -> WorkoutSet
func updateSet(_ set: WorkoutSet) async throws -> WorkoutSet
func deleteSet(id: UUID) async throws
func completeSession(_ sessionId: UUID, endedAt: Date) async throws
```

Implementation notes:

- Prefer insert/update payload structs so server-managed fields are not accidentally sent.
- Keep `ErrorMapper.map(error, context:)` in every catch block with operation/table context.
- Use existing RLS for ownership enforcement.
- Do not introduce `RepositoryError`; use `AppError`.

---

## 9. Localization

Add complete Thai and English copy for these key families:

```text
workout.*
workout.restore.*
workout.set.*
workout.timer.*
workout.finish.*
workout.sync.*
accessibility.workout.*
```

Include all titles, messages, buttons, errors, empty states, retry actions, timer labels, and icon-only button labels.

---

## 10. Testing And Acceptance

Automated tests:

- backup encode/decode round trip
- backup version mismatch
- set validation
- add set copies previous values
- delete set renumbers remaining rows
- timer remaining calculation from dates
- ViewModel start success path with mock repositories
- ViewModel upload failure and retry
- finish does not clear backup when completion fails
- finish clears backup when completion succeeds

Manual smoke test:

```text
1. Create or open a program day with exercises.
2. Start workout.
3. Complete multiple sets.
4. Add and delete a set.
5. Confirm rest timer appears and completes.
6. Force relaunch before finishing.
7. Restore the active session.
8. Finish workout.
9. Confirm backup is cleared and no restore prompt appears on next launch.
```

Build/test:

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'
```
