# Sprint 2 - Custom Program Builder Implementation Plan

> **For agentic workers:** Read `.claude/GYMTRACK.md`, this sprint's `spec.md`, and the `CURRENT STATUS` block before starting. Mark each checkbox `[x]` immediately after completing it. Preserve unrelated user changes.

**Goal:** Build a custom program builder so a signed-in user can create, edit, activate, and delete a complete Upper/Lower 4-day lifting program.

---

## CURRENT STATUS

**Status:** Tasks 1, 2, 3, and 4 complete. Task 5 wiring, integration, and verification is ready to start.

**Done:**
- Sprint 2 spec created at `.claude/sprints/S02-program-builder/spec.md`.
- Sprint 2 plan created at `.claude/sprints/S02-program-builder/plan.md`.
- Shared Program protocols created for list, builder, detail, day builder, and exercise picker.
- `ProgramExerciseForm`, validation helpers, zero-based dense order helpers, preview samples, and Swift Testing coverage added.
- All Sprint 2 SwiftUI Program screens built with localized keys and protocol-based ViewModels (Task 3).
- Full localization keys and Thai/English translations added to `Localizable.xcstrings` (Task 4).
- Targeted Task 1 tests pass on `iPhone 17e`.
- Task 2 repository methods, payload structs, concrete ViewModels, and Swift Testing coverage added.
- Targeted Task 2 tests pass on `iPhone 17e`.
- Full `xcodebuild test` scheme passes on `iPhone 17e`.

**Last commit SHA:** 9c7068f

**Known deviations / constraints:**
- Use simulator `iPhone 17e` in all `xcodebuild` commands.
- Module name is `Gymbros`.
- Tests use Swift Testing, not XCTest.
- Xcode 16 auto-discovers files under `Gymbros/`; do not edit `project.pbxproj` just to add files.
- Do not manually declare `Color.gymPurple`; it is generated from the asset catalog.
- No schema migration is expected for Sprint 2.
- Verification required escalated filesystem/CoreSimulator access because sandboxed `xcodebuild` could not write SwiftPM/Xcode caches.
- The worktree uses an ignored local placeholder `Gymbros/Core/Secrets.swift` with dummy values so tests compile; do not commit real secrets.
- Task 2 added repository protocols solely for dependency injection in ViewModel tests; concrete app code still defaults to `ProgramRepository` and `ExerciseRepository`.

**Next step:** Start Task 5 wiring, integration, and verification.

---

## Parallel Execution Map

Task 1 is sequential and unlocks parallel work.

After Task 1 is complete, these can run in parallel:

- **Task 2 - Data + ViewModels:** Codex or one worker owns repositories, concrete ViewModels, validation tests.
- **Task 3 - SwiftUI Views:** Gemini/Claude/Codex worker owns Program screens and previews only.
- **Task 4 - Localization:** Another worker owns `Localizable.xcstrings` and small shared localized UI helpers only.

Task 5 is sequential integration after Tasks 2-4 are complete.

---

## Task 1: Shared Contracts And Form State

**Owner:** Sequential first worker.

**Files likely touched:**
- `Gymbros/Presentation/Programs/ProgramBuilderProtocol.swift`
- `Gymbros/Presentation/Programs/ProgramListProtocol.swift`
- `Gymbros/Presentation/Programs/ProgramDetailProtocol.swift`
- `Gymbros/Presentation/Programs/DayBuilderProtocol.swift`
- `Gymbros/Presentation/Programs/ExercisePickerProtocol.swift`
- `Gymbros/Presentation/Programs/ProgramExerciseForm.swift`
- `Gymbros/Presentation/Programs/ProgramSamples.swift`
- `GymbrosTests/ProgramBuilderValidationTests.swift`

**Rules:**
- Define protocols before concrete ViewModels and views diverge.
- Keep shared contracts minimal but complete enough for UI and data workers.
- Do not implement Supabase mutations in this task.

- [x] Define `ProgramListProtocol` with list state, transient error, load, set active, and delete methods.
- [x] Define `ProgramBuilderProtocol` and `ProgramBuilderMode`.
- [x] Define `ProgramDetailProtocol` and `ProgramDetailData`.
- [x] Define `DayBuilderProtocol` and `DayBuilderData`.
- [x] Define `ExercisePickerProtocol`.
- [x] Add `ProgramExerciseForm` with default targets: 3 sets, 8-12 reps, 90 seconds rest.
- [x] Add validation helpers for program name, day name, sets, rep range, rest seconds, and notes trimming.
- [x] Add reorder/order-normalization helper for days and program exercises using zero-based dense order.
- [x] Add preview sample data that does not require network/auth.
- [x] Add Swift Testing coverage for validation defaults and order normalization.
- [x] Run `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/ProgramBuilderValidationTests`.
- [x] Update `CURRENT STATUS` with completed work, deviations, and next parallel tasks.

---

## Task 2: Data And Concrete ViewModels

**Owner:** Data/ViewModel worker.

**Parallel-safe ownership:** Do not edit SwiftUI view files except if needed to satisfy protocol compile errors created by Task 1. Do not edit localization except temporary keys if Task 4 is unavailable.

**Files likely touched:**
- `Gymbros/Data/Repository/ProgramRepository.swift`
- `Gymbros/Data/Repository/ExerciseRepository.swift`
- `Gymbros/Presentation/Programs/*ViewModel.swift`
- `GymbrosTests/ProgramRepositoryPayloadTests.swift`
- `GymbrosTests/ProgramBuilderValidationTests.swift`

- [x] Extend `ProgramRepository` with create/update/delete/reorder methods for `program_days`.
- [x] Extend `ProgramRepository` with create/update/delete/reorder methods for `program_exercises`.
- [x] Use insert/update payload structs so server-managed fields are not sent accidentally.
- [x] Ensure repository catch blocks map errors through `ErrorMapper` with operation/table context.
- [x] Implement concrete `ProgramListViewModel` conforming to `ProgramListProtocol`.
- [x] Implement `ProgramBuilderViewModel` for create/edit program metadata.
- [x] Implement `ProgramDetailViewModel` for full program load, active action, delete program, day add/rename/delete/reorder.
- [x] Implement `DayBuilderViewModel` for day load, exercise add/update/delete/reorder.
- [x] Implement `ExercisePickerViewModel` with fetch-all once and in-memory search/filter.
- [x] Ensure all ViewModels use `ViewState` and expose only `AppError` for errors.
- [x] Add tests for payload encoding if payload structs are introduced.
- [x] Add tests for ViewModel validation paths that do not require live Supabase.
- [x] Run relevant Swift tests.
- [x] Update `CURRENT STATUS` with completed work and any integration notes for Task 5.

---

## Task 3: SwiftUI Program Screens

**Owner:** UI worker.

**Parallel-safe ownership:** Use protocols and preview/stub ViewModels from Task 1. Do not edit repositories or concrete data ViewModels.

**Files likely touched:**
- `Gymbros/Presentation/Programs/ProgramListView.swift`
- `Gymbros/Presentation/Programs/ProgramBuilderView.swift`
- `Gymbros/Presentation/Programs/ProgramDetailView.swift`
- `Gymbros/Presentation/Programs/DayBuilderView.swift`
- `Gymbros/Presentation/Programs/ExercisePickerView.swift`
- `Gymbros/Presentation/Programs/ProgramExerciseEditorView.swift`

- [x] Build `ProgramListView` with loading, empty, success, error, create, active, delete confirmation, and navigation.
- [x] Build `ProgramBuilderView` with create/edit modes, name/description form, validation, save, and cancel.
- [x] Build `ProgramDetailView` with program header, active action, day list, add/rename/delete/reorder days, edit/delete program entry points.
- [x] Build `DayBuilderView` with day rename, add exercise, exercise row list, prescription edit, delete, and reorder.
- [x] Build `ExercisePickerView` with search, muscle/equipment/pattern filters, clear filters, empty results, and selection callback.
- [x] Do not add custom exercise creation in Sprint 2; roadmap places that in Sprint 8.
- [x] Build `ProgramExerciseEditorView` with sets, rep min/max, rest presets, notes, validation, save, and cancel.
- [x] Ensure icon-only buttons have accessibility labels.
- [x] Ensure primary tap targets are at least 48pt.
- [x] Ensure previews compile without live Supabase or concrete data ViewModels.
- [x] Avoid hardcoded user-facing strings; use localized keys.
- [x] Run a build or targeted preview-compatible compile check.
- [x] Update `CURRENT STATUS` with completed work and any integration notes for Task 5.

---

## Task 4: Localization And Copy

**Owner:** Localization/UI-support worker.

**Parallel-safe ownership:** Own `Localizable.xcstrings`. Coordinate before editing shared Swift files.

**Files likely touched:**
- `Gymbros/Resources/Localizable.xcstrings`

- [x] Add `common.*` keys needed by Sprint 2: save, cancel, delete, edit, done, retry, seconds, minutes, active, search.
- [x] Add `programs.*` keys for list title, empty state, create action, active badge, delete confirmation, and loading/error copy.
- [x] Add `programBuilder.*` keys for create/edit titles, fields, placeholders, and validation messages.
- [x] Add `programDetail.*` keys for day management, active action, edit action, delete action, and confirmations.
- [x] Add `dayBuilder.*` keys for add exercise, rename day, exercise count, reorder labels, and confirmations.
- [x] Add `exercisePicker.*` keys for search, filters, clear filters, no results, and exercise metadata.
- [x] Add `programExercise.*` keys for sets, reps, rep range, rest, notes, presets, and validation.
- [x] Add `accessibility.*` keys for all icon-only buttons and destructive actions.
- [x] Verify every new key has both `en` and `th` localizations marked translated.
- [x] Search for hardcoded Sprint 2 user-facing strings in `Gymbros/Presentation/Programs`.
- [x] Update `CURRENT STATUS` with completed work and any missing keys for Task 5.

---

## Task 5: Wiring, Integration, And Verification

**Owner:** Final integration worker.

**Start only after:** Tasks 2, 3, and 4 are complete or explicitly handed off.

**Files likely touched:**
- `Gymbros/App/RootView.swift`
- `Gymbros/Presentation/Programs/*`
- `Gymbros/Resources/Localizable.xcstrings`
- Tests as needed

- [ ] Wire authenticated `RootView` to `ProgramListView` for Sprint 2.
- [ ] Replace preview/stub ViewModel injection at runtime with concrete ViewModels.
- [ ] Confirm create program flow navigates to detail or refreshes list as specified.
- [ ] Confirm edit program flow refreshes detail/list state.
- [ ] Confirm day add/rename/delete/reorder updates Supabase and local state.
- [ ] Confirm exercise add/edit/delete/reorder updates Supabase and local state.
- [ ] Confirm active program behavior clears previous active program after refresh.
- [ ] Confirm delete confirmations are present for programs and non-empty days.
- [ ] Run `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'`.
- [ ] Manually create the full Upper/Lower 4-day acceptance routine in the simulator.
- [ ] Reopen the app and verify saved program data reloads.
- [ ] Search for hardcoded Sprint 2 user-facing strings.
- [ ] Check `git diff` for accidental secrets or unrelated changes.
- [ ] Update `CURRENT STATUS`: mark Sprint 2 complete, list test command result, last commit SHA if committed, known deviations, and next step.

---

## Acceptance Checklist

- [ ] Program list works for empty and non-empty users.
- [ ] Program create/edit/delete works.
- [ ] One active program works.
- [ ] Days can be added, renamed, deleted, and reordered.
- [ ] Exercises can be searched, filtered, added, edited, deleted, and reordered.
- [ ] Target sets, rep range, and rest seconds persist.
- [ ] All visible strings are localized in Thai and English.
- [ ] No raw SDK/database errors reach SwiftUI.
- [ ] Automated tests pass.
- [ ] Upper/Lower 4-day manual smoke test passes.
 SwiftUI.
- [ ] Automated tests pass.
- [ ] Upper/Lower 4-day manual smoke test passes.
