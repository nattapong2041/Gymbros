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
✓ WorkoutSessionView as a paged TabView, one exercise per page
✓ WorkoutExercisePageView per exercise with header, set list, Add Set, and
  Finish Exercise
✓ Top progress header: Day name · X / N · K done
✓ Free swipe between unfinished exercise pages (supports supersets and
  alternating workouts informally; no formal grouping in Sprint 3)
✓ Per-exercise default weight resolves from ProgramExercise.targetWeight →
  last-logged fallback → blank
✓ Set 1 weight pre-fills from default weight
✓ Set 2+ pre-fills weight and reps from the previous set's actual logged
  values (RPE stays blank per set)
✓ Finish Exercise locks the page, sets isFinished and finishedAt, and
  auto-advances to the next unfinished page
✓ Finished exercise pages are read-only for the rest of the session;
  no resume prompt when tapped
✓ Finish Workout enables only when every exercise is finished
✓ Concrete WorkoutSessionViewModel using @Observable
✓ In-memory active session state while the app is running
✓ ActiveSessionBackup using Codable JSON in UserDefaults (versioned,
  includes finishedExerciseIds and currentExerciseIndex)
✓ Session-level Crash/relaunch recovery prompt with Restore and Discard
  actions; Restore lands on the first unfinished exercise
✓ SetRowView with weight, reps, RPE, completion, and sync status
✓ Add set per exercise, copying the previous set values when available
✓ Swipe/delete an unneeded set
✓ Background async upload per completed set
✓ Retry failed set upload
✓ RestTimerRingView using target rest seconds from ProgramExercise;
  triggers on set completion regardless of which page the user is on
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
✗ Cross-session progressive overload suggestions (intra-exercise carry-over only)
✗ Exercise substitution / defer / skip flows
✗ True offline-first sync queue
✗ Editing past sets of finished exercises in the active session
  (handled by History in a later sprint)
✗ Formal superset grouping (paired pages with a group_id column) —
  Sprint 3 supports supersets via free-swipe between unfinished pages
```

Note: Sprint 3 does add **one** schema change — `program_exercises.target_weight` (nullable). This is the only schema change in Sprint 3 and is subject to the Data Safety approval rule in `CLAUDE.md`.

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
- The whole app uses SwiftUI system and semantic colors only. Do not use `Color.gymAccent`, `Color.gymPurple`, `Color.gymAccentText`, custom named color assets, hex literals, or `Color(red:green:blue:)` in app UI.

---

## 2.1 Spec Lock Decisions

Task 0 locks these shared decisions before parallel work starts:

- Use a concrete `@Observable WorkoutSessionViewModel`; do not create a ViewModel protocol.
- Task 1 owns the shared workout state structs used by both the ViewModel and views.
- Active session backup follows `Data/Local -> Data/Repository -> ViewModel`: `ActiveSessionBackupStore` handles UserDefaults JSON, `ActiveSessionBackupRepository` is the ViewModel-facing data boundary, and `WorkoutSessionViewModel` does not call local storage directly.
- Backup DTOs live in `Gymbros/Data/Local/ActiveSessionBackupModels.swift`; UI-facing workout row state stays in `Gymbros/Presentation/Workout/WorkoutSessionState.swift`.
- `WorkoutSetRowState.syncState` uses: `pending`, `uploading`, `uploaded`, `failed(AppError)`.
- `ActiveSessionSnapshot` is versioned Codable JSON in `UserDefaults`; it must not store secrets, tokens, or auth headers.
- Restore decode failure or version mismatch maps to `.decoding` and offers Discard only.
- All repository errors crossing into ViewModels must be `AppError`.
- Task 4 owns runtime wiring from `DayBuilderView` to `WorkoutSessionView`.

Additions (Realignment 2026-05-11):

- `WorkoutSessionData` gains `currentExerciseIndex: Int`.
- `WorkoutExerciseSection` gains `isFinished: Bool`, `finishedAt: Date?`, and `defaultWeight: Double?`.
- `ActiveSessionSnapshot` gains `finishedExerciseIds: [UUID]` and `currentExerciseIndex: Int`.
- The logger uses a paged `TabView` (`.tabViewStyle(.page(indexDisplayMode: .never))`) with one `WorkoutExercisePageView` per exercise.
- Set completion does **not** advance the page. Only the explicit `finishExercise(programExerciseId:)` action advances `currentExerciseIndex`.
- Free swipe between unfinished pages is the supported superset/alternating UX.
- Restore recomputes `currentExerciseIndex` to the first `!isFinished` section regardless of the saved value.
- Default weight per exercise resolves at session start: `ProgramExercise.targetWeight` → last-logged weight for that exercise → blank.
- Set 2+ weight and reps pre-fill from the previous set's actual logged values inside the same exercise. RPE is always blank per set.
- Color policy: the whole app uses SwiftUI system and semantic colors only. Custom lime/purple brand colors are deferred because the lime treatment is not readable enough on light backgrounds.

---

## 3. Product Flow

Sprint 4 will introduce Today navigation. Sprint 3 uses a temporary start path from the existing program/day flow:

```text
ProgramListView
→ ProgramDetailView
→ DayBuilderView (with target_weight per program exercise)
→ Start Workout
→ WorkoutSessionView (paged TabView)
      page 1: Exercise A — log sets → Finish Exercise
      page 2: Exercise B — log sets → Finish Exercise
      ...
      all finished → Finish Workout enabled
```

Rules:

- Show Start Workout only when the day has at least one exercise.
- Starting creates a `workout_sessions` row immediately.
- If an unfinished local backup exists, show Restore / Discard before allowing a new session.
- Restoring opens the saved session state and lands on the first unfinished exercise page.
- Discarding clears the local backup and may optionally delete the remote incomplete session if the repository supports it safely.
- Within a session, the user can swipe freely between any unfinished exercise pages (supports supersets and alternating workflows).
- Finished pages remain swipable but become read-only — no resume prompt, no edit affordance.
- Finish Workout becomes available only when every exercise on the day is marked finished.

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
    func finishExercise(programExerciseId: UUID) async
    func goToExercise(index: Int)
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
currentExerciseIndex: Int   // 0-based; drives TabView page selection
```

`WorkoutExerciseSection`:

```text
programExercise: ProgramExercise
exercise: Exercise?
sets: [WorkoutSetRowState]
isFinished: Bool
finishedAt: Date?
defaultWeight: Double?       // resolved: targetWeight → last-logged → nil
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
- Initialize `currentExerciseIndex = 0`.
- For each `ProgramExercise`, resolve `defaultWeight`:
  - First: `programExercise.targetWeight`.
  - Else: most recent logged weight for that exercise from `WorkoutRepository` history.
  - Else: nil (blank).
- Create local draft rows for each exercise based on `target_sets`. Set 1's `weightText` = format(`defaultWeight`) or empty. Set 1 reps default to `target_reps_min`. Sets 2..N start blank — they pre-fill from the previous set's **actual** values at completion time.
- Each exercise starts with `target_sets` editable rows, `isFinished = false`, `finishedAt = nil`.

### Completing A Set

- Validate weight and reps before upload.
- Weight must be numeric and `>= 0`.
- Reps must be an integer in `1...100`.
- RPE is optional; if present it must be in `1.0...10.0`.
- On completion, save backup immediately.
- Upload the set in the background.
- Show sync state per row.
- Start rest timer using the row's `targetRestSeconds` when available.
- Carry-over: if a next set row exists for the **same** exercise and that row is not yet completed and its `weightText`/`repsText` are blank or still match the default, copy the just-logged actual `weightText` and `repsText` into it. Do not copy RPE.
- Set completion does **not** advance the TabView page.

### Finish Exercise

- Requires at least one set in the section to be `isCompleted == true` and `syncState == .uploaded`.
- Sets `isFinished = true`, `finishedAt = now` on the section.
- Save backup immediately.
- Advance `currentExerciseIndex` to the next section where `isFinished == false`. If none, leave the index on the just-finished page.
- Does not start a new rest timer (timers only fire on set completion).
- After finishing, the page is read-only: no input edits, no Add Set, no Finish Exercise button, no resume prompt when the user swipes back.

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

- Enabled only when every exercise section has `isFinished == true`.
- Disable duplicate finish actions while finishing.
- Retry or wait for pending uploads before marking complete.
- Call repository `completeSession(sessionId:endedAt:)`.
- Clear local backup only after remote completion succeeds.
- Leave backup in place if completion fails.

---

## 6. Backup And Restore

Use `UserDefaults` with versioned Codable JSON.

Layering:

- `Gymbros/Data/Local/ActiveSessionBackupStore.swift`: encodes/decodes and clears the JSON blob.
- `Gymbros/Data/Local/ActiveSessionBackupModels.swift`: contains the Codable backup snapshot DTOs.
- `Gymbros/Data/Repository/ActiveSessionBackupRepository.swift`: exposes backup load/save/clear to the ViewModel.
- `WorkoutSessionViewModel` maps backup DTO rows to `WorkoutSetRowState` and back.

`ActiveSessionSnapshot`:

```text
version: Int
session: WorkoutSession
day: ProgramDay
programExercises: [ProgramExercise]
exerciseLookup: [UUID: Exercise]
rowStates: [WorkoutSetRowState]
finishedExerciseIds: [UUID]      // programExercise IDs marked finished
currentExerciseIndex: Int        // last-known page; recomputed on restore
defaultWeights: [UUID: Double]?  // per programExerciseId, resolved at start
activeTimer: RestTimerState?
updatedAt: Date
```

Rules:

- Use a single key such as `activeWorkoutSessionBackup`.
- Decode failure maps to `.decoding`; offer Discard.
- Version mismatch offers Discard.
- Bumping the schema (new fields above) requires incrementing the `version` constant.
- Backup after every meaningful local mutation (set complete, set add/delete, finish exercise, restore reconcile).
- On restore, recompute `currentExerciseIndex` to the first section whose programExercise ID is **not** in `finishedExerciseIds`. Do not trust the saved index for navigation.
- Tapping a finished exercise page after restore must not produce any resume prompt.
- Clear backup after successful finish or explicit discard.
- Do not store secrets or auth tokens in backup.

---

## 7. UI Requirements

### WorkoutSessionView

States:

- loading: progress indicator
- empty: no exercises in this day
- success: paged `TabView` of `WorkoutExercisePageView` pages with a custom progress header and Finish Workout action
- error: localized retry UI
- restore prompt: Restore and Discard (session-level only)

Success layout:

- Custom header at the top: program day name • `X / N` progress (current page / total) • `K done` count (count of `isFinished == true` sections).
- Below header: `TabView { ForEach exerciseSections } WorkoutExercisePageView`.
  - `.tabViewStyle(.page(indexDisplayMode: .never))`.
  - Selection bound to `currentExerciseIndex`.
- Finish Workout action sits in the navigation bar trailing item. It is disabled while finishing **and** disabled until every section's `isFinished == true`.
- Color policy: use default SwiftUI styling and system/semantic colors only. If an explicit tint is required, use an adaptive system color that matches the meaning (`.blue` for primary action, `.green` for success/completion, `.orange` for warning/recovery, `.red` for destructive/error, `.purple` only for comeback/PR/milestone semantics).

### WorkoutExercisePageView

One per `WorkoutExerciseSection`. Layout:

- Header: exercise name, target prescription `targetSets × targetRepsMin-targetRepsMax · targetRestSeconds s`, target weight (if any), notes.
- Set list: `SetRowView` per row. Add Set button under the list.
- Footer: Finish Exercise button.
- Finished mode: when `isFinished == true`:
  - All inputs disabled (including Add Set).
  - Sync icons hidden (everything is uploaded by definition).
  - Replace the Finish Exercise button with a non-interactive ✓ "Finished" badge using default/semantic SwiftUI styling; use `.green` only if an explicit completion tint is needed.
  - No resume prompt when the user swipes to this page.

Each set row has editable weight, reps, optional RPE, completion checkbox/button, and sync status (except in finished mode). Add Set action appears per exercise (except in finished mode).

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
workout.exercise.finish
workout.exercise.finished
workout.exercise.next
workout.exercise.target_weight
workout.progress.count          // e.g. "%lld / %lld"
workout.progress.done           // e.g. "%lld done"
program.exercise.target_weight  // program-builder field label
accessibility.workout.*
```

Include all titles, messages, buttons, errors, empty states, retry actions, timer labels, and icon-only button labels.

---

## 10. Testing And Acceptance

Automated tests:

- backup encode/decode round trip (including `finishedExerciseIds`, `currentExerciseIndex`)
- backup version mismatch
- set validation
- add set copies previous values
- delete set renumbers remaining rows
- timer remaining calculation from dates
- ViewModel start success path with mock repositories
- ViewModel upload failure and retry
- finish does not clear backup when completion fails
- finish clears backup when completion succeeds
- `finishExercise` marks `isFinished = true` and advances `currentExerciseIndex` to the next unfinished section
- restore recomputes `currentExerciseIndex` to the first `!isFinished` section even when the snapshot points elsewhere
- completing set N copies its actual `weightText` and `repsText` (not RPE) into the unmodified set N+1 within the same exercise
- default-weight resolution prefers `programExercise.targetWeight` over last-logged history, and falls back to blank when neither exists

Manual smoke test:

```text
1. Program builder: add two exercises with target weights
   (e.g. Hammer Curl 12 kg, Rope Pushdown 25 kg).
2. Start workout. First page shows Hammer Curl with set 1 weight pre-filled to 12.
3. Log Hammer Curl set 1 at 14 kg (heavier than target). Rest timer starts.
4. Swipe to Rope Pushdown. Log set 1 at 25 kg. Rest timer restarts.
5. Swipe back to Hammer Curl. Set 2 weight pre-fills with 14 kg
   (the actual from set 1). Log it.
6. Complete all Hammer Curl sets. Tap Finish Exercise — page auto-advances
   to the next unfinished page.
7. Swipe back to Hammer Curl. Inputs are disabled, no Finish prompt,
   no restore prompt.
8. Force-relaunch mid Rope Pushdown. Restore prompt appears. Restore opens
   Rope Pushdown directly.
9. Finish all exercises. Finish Workout enables. Tap it. Backup cleared and
   no restore prompt appears on next launch.
```

Build/test:

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'
```
