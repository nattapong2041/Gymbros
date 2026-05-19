# STANDUP — Session Handoff

> Update this file at the start and end of every session (date, HEAD SHA, last-done, next-up, open follow-ups).

---

**Last updated:** 2026-05-19 | HEAD `b59cd8e` | Branch `main` (Sprint 4 Tasks 1 and 5 changes uncommitted)

---

## Where we are

Phase 1 ("Real Life Works") is ~75% done — Sprints 1–3 complete. Sprint 4 is in progress. Settings was split into its own Sprint 5; old Sprints 5–13 renumbered to 6–14.

| Sprint | Name | Status |
|--------|------|--------|
| S01 | Foundation + Data | complete |
| S02 | Custom Program Builder | complete |
| S03 | Logger + Timer | complete |
| **S04** | **Today + History + Navigation + Anti-Guilt UX** | **in progress** |
| S05 | Settings | not started |
| S06 | Next Best Session v1 / Smart Comeback | not started |

---

## Last session did

- Sprint 4 Task 5 — TodayView + mock data + previews:
  - Added `Gymbros/Presentation/Today/TodayView.swift` and `Gymbros/Presentation/Today/TodayMockData.swift`.
  - Covered loading, error, no-program, active-program/no-history, streak, and welcome-back preview states.
  - Start CTA pushes `WorkoutSessionScreen(programDayId:)` via `.navigationDestination(item:)`.
  - Updated Today CTAs to use local `ButtonStyle` implementations instead of per-button `controlSize`, following Apple HIG style/content/role guidance for iPhone and iPad consistency.
  - `TodayViewData` is a UI-only mirror for Task 5; Task 8 should map/collapse it to the real `TodayData` from Task 2.
  - Verified with `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`.
- Sprint 4 Task 1 — `fetchSets` + `StreakService` + tests:
  - Added `func fetchSets(sessionId: UUID) async throws -> [WorkoutSet]` to `WorkoutRepositoryProviding` protocol and `WorkoutRepository` concrete class. Ordered by `exercise_id` then `set_number`; returns `[]` for empty; maps through `ErrorMapper`.
  - Updated private `FakeWorkoutRepository` in `WorkoutSessionViewModelTests.swift` with `sets`, `fetchSetsError`, and the method so the test target stays compilable.
  - Created `Gymbros/Data/Services/StreakService.swift` — pure Swift struct, `Calendar(identifier: .iso8601)`, groups by `session.startedAt`, returns `count >= 2 ? count : 0`.
  - Created `GymbrosTests/StreakServiceTests.swift` — 9 tests (zero/current-week/one-prior/two-consecutive/five-consecutive/gap/incomplete-excluded/incomplete-mixed/year-boundary), all pass.
  - All existing `WorkoutSessionViewModelTests` still pass.

## Previous session did

- Fixed two S03 workout-session regressions (rest timer background, restore sheet path).
- Task 0 (Spec Lock) for Sprint 4: 8 ambiguities locked in `spec.md` §2.2.

---

## Next up

**Sprint 4 — Tasks 2–4, 6–7 remain (can run in parallel), then Task 8 (sequential)**

1. ~~Task 1: done — `fetchSets` + `StreakService` + tests.~~
2. Task 2: Create `TodayViewModel` + tests.
3. Task 3: Create `HistoryViewModel` + `SessionDetailViewModel` + tests.
4. Task 4: Replace `RootView` authenticated branch with `TabView` shell (Today/Programs/History).
5. ~~Task 5: done — `TodayView` + mock data + previews.~~
6. Task 6: Build `HistoryView` + `SessionDetailView` + mock data + previews.
7. Task 7: Add all Sprint 4 localization keys (Thai + English) to `Localizable.xcstrings`.
8. Task 8: Wire everything together, run tests, smoke test.

---

## Open follow-ups

- [ ] Light/dark visual sweep of `WorkoutSessionView`, `WorkoutExercisePageView`, `SetRowView`, `RestTimerRingView`, `ProgramExerciseEditorView` in Xcode before broad TestFlight.
- [ ] Task 8: map/collapse `TodayViewData` into the real `TodayData` once `TodayViewModel` lands, and wire `onShowPrograms` to tab selection.
- [ ] Confirm S05 Settings rows at Task 0 of Sprint 5 before any code lands (weight unit toggle, sign out, app version, privacy placeholder, delete placeholder).

---

## How to resume

1. Read this file.
2. Read `.claude/sprints/S04-today-history/spec.md` for Sprint 4 scope.
3. Read `.claude/sprints/S04-today-history/plan.md` — start at the first unchecked task.
4. Update the `## CURRENT STATUS` block in the sprint plan as you go.
5. Update this file before ending the session.
