# Sprint 2 - Custom Program Builder

> Detailed implementation spec for coding agents.
> Reference: `.claude/GYMTRACK.md` Section 7 - Phase 1, Sprint 2

---

## Overview

**Goal:** Let a signed-in user create, edit, activate, and delete a custom lifting program from the app.

**Primary acceptance test:** The developer can manually create the full Upper/Lower 4-day routine from `.claude/GYMTRACK.md` Section 9, navigate the saved program, mark it active, close/reopen the app, and see the saved structure again.

**Effort estimate:** Complex.

**Dependencies:** Sprint 1 is complete: auth, Supabase schema, models, repositories, localization, error handling, and color assets exist.

---

## 1. Requirements

### Must Have

```
✓ Authenticated users can view their programs
✓ Empty state explains that no program exists yet
✓ Users can create a program with name and optional description
✓ Users can edit program name and description
✓ Users can delete a program after confirmation
✓ Users can mark exactly one program active
✓ Users can add, rename, delete, and reorder program days
✓ Users can add, remove, and reorder exercises inside a day
✓ Users can search and filter the exercise library
✓ Users can set target sets, rep range, and rest seconds per exercise
✓ All user-visible strings are localized in Thai and English
✓ All user-visible errors flow through AppError/ViewState
✓ App builds and tests pass on iPhone 17e simulator
```

### Out of Scope

```
✗ Workout logging (Sprint 3)
✗ Today screen next-workout logic (Sprint 4)
✗ Starter templates and template cloning (Sprint 4 / Sprint 8)
✗ Exercise substitution (Sprint 8)
✗ Custom user-created exercises (Sprint 8)
✗ Program sharing
✗ Offline editing or conflict resolution UI beyond friendly AppError copy
```

---

## 2. Existing Foundation To Reuse

Use the current Sprint 1 files and conventions:

```
Gymbros/Model/Program.swift
Gymbros/Model/ProgramDay.swift
Gymbros/Model/ProgramExercise.swift
Gymbros/Model/Exercise.swift
Gymbros/Data/Repository/ProgramRepository.swift
Gymbros/Data/Repository/ExerciseRepository.swift
Gymbros/Core/ErrorHandling/AppError.swift
Gymbros/Core/ErrorHandling/ViewState.swift
Gymbros/Presentation/Programs/ProgramListViewModel.swift
Gymbros/Resources/Localizable.xcstrings
```

Rules:

- Keep models `Codable` with explicit `CodingKeys`.
- Do not add nested relationship properties to `CodingKeys`.
- Use `@Observable`, not `ObservableObject`.
- Keep repositories `@MainActor`.
- Repository methods may be `async throws`, but anything thrown outside the data layer must be `AppError`.
- Do not expose raw Supabase errors, SQL details, status codes, or `localizedDescription` in SwiftUI.
- Do not add `Color.gymPurple` manually; Xcode auto-generates it from the named color asset.

---

## 3. Data Behavior

### Program

Programs use the existing `programs` table.

Required UI fields:

```
name: required after trimming whitespace
description: optional; save nil when trimmed value is empty
isActive: controlled by active action, not by the edit form
```

List sorting:

```
Primary: active program first
Secondary: updatedAt descending
```

Create behavior:

- User taps Create New from `ProgramListView`.
- App opens `ProgramBuilderView`.
- Save inserts a `programs` row with `user_id = AuthService.shared.currentUser.id`.
- A new program is not active automatically unless product behavior is explicitly changed later.
- After save, navigate to `ProgramDetailView` for the created program.

Edit behavior:

- User edits only name and description in Sprint 2.
- Save updates the existing `programs` row.
- Refresh detail/list state after a successful save.

Delete behavior:

- User must confirm deletion.
- Delete the program row only.
- Existing foreign keys cascade delete `program_days` and `program_exercises`.
- If the deleted program was active, no replacement is automatically selected in Sprint 2.

Active behavior:

- Use existing `ProgramRepository.setActive(programId:)`.
- Existing database trigger `single_active_program` clears other active programs for the user.
- UI refreshes after setting active.
- If the database returns conflict or permission errors, show friendly localized AppError UI.

### Program Days

Days use the existing `program_days` table.

Fields:

```
program_id: parent program id
name: required after trimming
day_order: dense order value
```

Defaults:

```
New day name: "Day N" in English source key, localized display where appropriate
day_order: append at the end
```

Ordering:

- Use zero-based order values internally for new Sprint 2 writes: first day has `day_order = 0`.
- When loading existing data, sort by `day_order` ascending.
- After delete or reorder, normalize all remaining day orders to `0..<count`.
- Persist all changed order values before considering reorder complete.

Delete behavior:

- User must confirm deletion when the day contains exercises.
- Delete the `program_days` row only.
- Existing foreign key cascades delete `program_exercises`.
- Normalize remaining day orders after delete.

### Program Exercises

Exercises inside a day use the existing `program_exercises` table.

Fields:

```
program_day_id: parent day id
exercise_id: selected exercise id
target_sets: 1...10
target_reps_min: 1...100
target_reps_max: target_reps_min...100
target_rest_seconds: 15...600
exercise_order: dense order value
notes: optional; save nil when trimmed value is empty
```

Defaults:

```
target_sets: 3
target_reps_min: 8
target_reps_max: 12
target_rest_seconds: 90
exercise_order: append at the end
```

Ordering:

- Use zero-based order values internally for new Sprint 2 writes.
- When loading existing data, sort by `exercise_order` ascending.
- After delete or reorder, normalize all remaining exercise orders to `0..<count`.

Display:

- `ProgramExercise` stores only `exerciseId`, so views need exercise metadata from `ExerciseRepository`.
- Build an in-memory `[UUID: Exercise]` lookup in the relevant ViewModel.
- If exercise metadata is missing, show a localized fallback such as "Exercise unavailable" and keep the row editable/deletable.

---

## 4. Repository Contract

Extend `ProgramRepository` instead of creating feature-specific repository types.

Add methods equivalent to:

```swift
func createDay(programId: UUID, name: String, order: Int) async throws -> ProgramDay
func updateDay(id: UUID, name: String, order: Int) async throws -> ProgramDay
func deleteDay(id: UUID) async throws
func reorderDays(_ days: [ProgramDay]) async throws

func createProgramExercise(
    dayId: UUID,
    exerciseId: UUID,
    targetSets: Int,
    targetRepsMin: Int,
    targetRepsMax: Int,
    targetRestSeconds: Int,
    order: Int,
    notes: String?
) async throws -> ProgramExercise

func updateProgramExercise(_ programExercise: ProgramExercise) async throws -> ProgramExercise
func deleteProgramExercise(id: UUID) async throws
func reorderProgramExercises(_ exercises: [ProgramExercise]) async throws
```

Implementation notes:

- Prefer small insert/update payload structs so immutable server fields such as `created_at` are not accidentally sent on insert.
- For updates, send only editable fields.
- Add `ErrorMapper.map(error, context:)` in every catch block with operation and table context.
- Keep explicit filters on user-owned parent data where practical. Supabase RLS remains the enforcement layer.
- For bulk reorder, sequential updates are acceptable for Sprint 2 because list sizes are small.

Extend `ExerciseRepository` only if needed:

```swift
func search(
    query: String,
    muscle: MuscleGroup?,
    equipment: Equipment?,
    pattern: MovementPattern?
) async throws -> [Exercise]
```

The preferred Sprint 2 implementation is:

- Fetch all exercises once.
- Filter in the ViewModel by localized-insensitive name matching and enum filters.
- Keep server-side search for a later optimization if the exercise library grows significantly.

---

## 5. ViewModel Contracts

Define protocols before splitting parallel UI and data work.

### ProgramList

`ProgramListViewModel` should expose:

```swift
var state: ViewState<[Program]> { get }
var transientError: AppError? { get }
func loadPrograms() async
func setActive(_ program: Program) async
func delete(_ program: Program) async
```

### ProgramBuilder

Use for create/edit program name and description.

```swift
var mode: ProgramBuilderMode { get }
var name: String { get set }
var description: String { get set }
var state: ViewState<Program> { get }
var validationError: AppError? { get }
func save() async
```

`ProgramBuilderMode`:

```swift
enum ProgramBuilderMode: Equatable {
    case create
    case edit(Program)
}
```

### ProgramDetail

Owns full program loading and program-level actions.

```swift
var state: ViewState<ProgramDetailData> { get }
var transientError: AppError? { get }
func load() async
func setActive() async
func deleteProgram() async
func addDay() async
func renameDay(_ day: ProgramDay, name: String) async
func deleteDay(_ day: ProgramDay) async
func moveDays(from source: IndexSet, to destination: Int) async
```

`ProgramDetailData` should contain:

```swift
var program: Program
var exerciseLookup: [UUID: Exercise]
```

### DayBuilder

Owns one program day and its exercise rows.

```swift
var state: ViewState<DayBuilderData> { get }
var transientError: AppError? { get }
func load() async
func addExercise(_ exercise: Exercise) async
func updateExercise(_ programExercise: ProgramExerciseForm) async
func deleteExercise(_ programExercise: ProgramExercise) async
func moveExercises(from source: IndexSet, to destination: Int) async
```

`ProgramExerciseForm` must validate target sets, rep range, rest seconds, and notes trimming before repository calls.

### ExercisePicker

```swift
var state: ViewState<[Exercise]> { get }
var searchText: String { get set }
var selectedMuscle: MuscleGroup? { get set }
var selectedEquipment: Equipment? { get set }
var selectedPattern: MovementPattern? { get set }
var filteredExercises: [Exercise] { get }
func loadExercises() async
func clearFilters()
```

---

## 6. SwiftUI Screens

Build screens under `Gymbros/Presentation/Programs/`.

### ProgramListView

Purpose:

- First signed-in screen for Sprint 2.
- Shows programs and lets user create/edit/activate/delete.

Required UI:

- `NavigationStack`.
- Title localized as Programs.
- Toolbar plus button for create.
- Empty state with create button.
- Loading state.
- Error state with retry.
- Program rows show name, optional description, number of days if available, and active badge.
- Swipe delete or row action delete with confirmation.
- Active action for inactive programs.

Navigation:

- Tap row -> `ProgramDetailView`.
- Plus -> `ProgramBuilderView(mode: .create)`.
- Edit from detail -> `ProgramBuilderView(mode: .edit(program))`.

### ProgramBuilderView

Purpose:

- Create/edit program metadata.

Required UI:

- Form with name and description.
- Save button disabled while invalid or loading.
- Cancel/dismiss.
- Inline validation text for missing name.
- Localized navigation title differs for create vs edit.

### ProgramDetailView

Purpose:

- Manage a full program's days.

Required UI:

- Program name and optional description.
- Active badge or Mark Active button.
- Add Day button.
- Editable/reorderable day list.
- Delete program confirmation.
- Day rows show name and exercise count.
- Tap day -> `DayBuilderView`.

### DayBuilderView

Purpose:

- Manage exercises inside one day.

Required UI:

- Rename day entry point.
- Add Exercise button opens `ExercisePickerView`.
- Exercise rows show exercise name, target sets, rep range, rest, and notes if present.
- Row edit sheet for target prescription.
- Delete exercise confirmation.
- Reorder exercises.

### ExercisePickerView

Purpose:

- Search/filter the existing exercise library and return a selected exercise.
- Sprint 2 does not include creating missing exercises from the picker; custom exercises are Sprint 8.

Required UI:

- Search field.
- Filter controls for primary muscle, equipment, and movement pattern.
- Clear filters action.
- List rows show exercise name, primary muscle, equipment, and compound/accessory hint.
- Tap row selects exercise and dismisses.
- Empty state for no search results.

### Prescription Editing

For Sprint 2, prescription editing may be a sheet or a pushed form.

Controls:

- Stepper or numeric field for sets.
- Numeric fields or steppers for min/max reps.
- Rest options should include common presets: 60, 90, 120, 180 seconds.
- Optional notes field.

Validation:

- Disable save for invalid values.
- Show localized inline validation.

---

## 7. Localization

Update `Gymbros/Resources/Localizable.xcstrings`.

Every new key must include complete `en` and `th` values.

Required string groups:

```
programs.*
programBuilder.*
programDetail.*
dayBuilder.*
exercisePicker.*
programExercise.*
validation.*
common.*
accessibility.*
```

Copy guidelines:

- Thai is primary and should sound natural, concise, and non-judgmental.
- English is fallback and should be short.
- Do not show raw numbers without units where rest duration is shown; use seconds or minutes in localized copy.
- Do not use guilt or streak language.

---

## 8. Accessibility And Design

Rules:

- Minimum tap target: 48pt.
- Use SwiftUI semantic colors for surfaces/text.
- Use `.gymAccent` for primary actions and active/completion emphasis.
- Use `.gymPurple` only for special states if needed; active program can use lime.
- Support Dynamic Type by avoiding fixed-height text containers.
- Icon-only buttons must have localized accessibility labels.
- Destructive actions use confirmation dialogs.
- Do not nest UI cards inside other cards.
- Do not hardcode user-facing strings in SwiftUI.

---

## 9. Testing

### Automated Tests

Use Swift Testing (`import Testing`).

Add coverage for:

- Program form validation: blank name fails, trimmed name saves, empty description becomes nil.
- Program day default naming and order normalization.
- Program exercise default targets.
- Program exercise validation: invalid sets, rep range, and rest values fail.
- Reorder helpers produce dense zero-based order.
- Payload structs encode snake_case keys and do not encode server-managed fields.

### Manual Smoke Test

Run:

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Then verify in simulator:

1. Sign in.
2. Open Programs list.
3. Create `Upper/Lower 4 Days`.
4. Add days:
   - Upper A
   - Lower A
   - Upper B
   - Lower B
5. Add exercises and targets from the routine below.
6. Reorder at least one day.
7. Reorder at least one exercise.
8. Mark the program active.
9. Close and reopen the app.
10. Confirm the program reloads and remains active.
11. Create a temporary test program and delete it after confirmation.

### Upper/Lower Acceptance Routine

```
Day 1 - Upper A
  Barbell Bench Press        4x5    rest 180s
  Barbell Bent Over Row      4x5    rest 180s
  Barbell Overhead Press     3x8    rest 120s
  Machine Lat Pulldown       3x10   rest 90s
  Cable Tricep Pushdown      3x12   rest 60s
  Dumbbell Bicep Curl        3x12   rest 60s

Day 2 - Lower A
  Barbell Back Squat         4x5    rest 180s
  Romanian Deadlift          3x8    rest 120s
  Leg Press                  3x10   rest 90s
  Leg Curl (Lying)           3x12   rest 60s
  Calf Raise (Standing)      4x15   rest 60s

Day 3 - Upper B
  Barbell Incline Bench      4x8    rest 120s
  Cable Row (Seated)         4x10   rest 120s
  Dumbbell Shoulder Press    3x10   rest 90s
  Machine Lat Pulldown       3x12   rest 90s
  Dumbbell Lateral Raise     3x15   rest 60s
  Cable Tricep Extension     3x15   rest 60s
  Dumbbell Hammer Curl       3x12   rest 60s

Day 4 - Lower B
  Barbell Deadlift           4x5    rest 180s
  Dumbbell Bulgarian SS      3x10   rest 90s
  Leg Extension              3x12   rest 60s
  Leg Curl (Seated)          3x12   rest 60s
  Barbell Hip Thrust         3x12   rest 90s
  Calf Raise (Seated)        3x15   rest 60s
```

---

## 10. Done Definition

Sprint 2 is done when:

- All Must Have requirements pass.
- The Upper/Lower acceptance routine can be created manually.
- Program data persists in Supabase and reloads after app restart.
- One active program behavior works.
- Delete confirmations work.
- Tests pass on `iPhone 17e`.
- No raw user-facing strings are introduced outside `Localizable.xcstrings`.
- `.claude/sprints/S02-program-builder/plan.md` has all tasks checked and current status updated.
