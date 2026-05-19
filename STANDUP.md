# STANDUP — Session Handoff

> Update this file at the start and end of every session (date, HEAD SHA, last-done, next-up, open follow-ups).

---

**Last updated:** 2026-05-19 | HEAD `a230556` | Branch `main`

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

- Sprint 4 Task 6 — HistoryView + SessionDetailView + mock data + previews:
  - Merged branch `worktree-s04-task6-history-ui` into `main`.
  - Added state-rendering `HistoryView` with loading, empty, error, and success states.
  - Added read-only `SessionDetailView` with duration and grouped set rows.
  - Added History mock data and previews for loading, empty/error, success, grouped sets, custom-workout fallback, and unknown-exercise fallback.
  - Retry buttons use default SwiftUI styling and colors, with no explicit button style or fixed sizing/control-size overrides.
  - History UI uses default SwiftUI colors only: no `Color(...)`, custom colors, `tint`, `foregroundStyle`, or `foregroundColor` overrides in `Gymbros/Presentation/History`.
  - Verified with `xcodebuild -quiet -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`.
- Completed Sprint 4 Task 7 in `.claude/worktrees/s04-task7-localization`, then merged it toward `main`.
  - Added all Sprint 4 Today, History, Session Detail, and accessibility localization keys to `Gymbros/Resources/Localizable.xcstrings`.
  - Added both canonical format keys and SwiftUI interpolation-shaped variants for Task 5/6 compatibility.
  - Verified `Localizable.xcstrings` parses with `jq empty`.
  - Verified all new Task 7 keys have both English and Thai values.
  - Noted that `Presentation/Today/` and `Presentation/History/` were not present in the isolated Task 7 base branch, so Task 8 must run the final hardcoded-string grep after UI branches merge.
- Sprint 4 Task 5 — TodayView + mock data + previews:
  - Added `Gymbros/Presentation/Today/TodayView.swift` and `Gymbros/Presentation/Today/TodayMockData.swift`.
  - Covered loading, error, no-program, active-program/no-history, streak, and welcome-back preview states.
  - Start CTA pushes `WorkoutSessionScreen(programDayId:)` via `.navigationDestination(item:)`.
  - Updated Today CTAs to use default SwiftUI button styles and default colors. Today UI now uses only SwiftUI semantic system color styles, with no custom/project color helpers or explicit accent colors.
  - `TodayViewData` is a UI-only mirror for Task 5; Task 8 should map/collapse it to the real `TodayData` from Task 2.
  - Verified with `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`.
- Sprint 4 Task 1 — `fetchSets` + `StreakService` + tests:
  - Added `func fetchSets(sessionId: UUID) async throws -> [WorkoutSet]` to `WorkoutRepositoryProviding` protocol and `WorkoutRepository` concrete class. Ordered by `exercise_id` then `set_number`; returns `[]` for empty; maps through `ErrorMapper`.
  - Updated private `FakeWorkoutRepository` in `WorkoutSessionViewModelTests.swift` with `sets`, `fetchSetsError`, and the method so the test target stays compilable.
  - Created `Gymbros/Data/Services/StreakService.swift` — pure Swift struct, `Calendar(identifier: .iso8601)`, groups by `session.startedAt`, returns `count >= 2 ? count : 0`.
  - Created `GymbrosTests/StreakServiceTests.swift` — 9 tests (zero/current-week/one-prior/two-consecutive/five-consecutive/gap/incomplete-excluded/incomplete-mixed/year-boundary), all pass.
  - All existing `WorkoutSessionViewModelTests` still pass.

## Earlier session did

- Fixed two S03 workout-session regressions (rest timer background, restore sheet path).
- Task 0 (Spec Lock) for Sprint 4: 8 ambiguities locked in `spec.md` §2.2.

---

## Next up

**Sprint 4 — Tasks 2–4 remain / need integration, then Task 8 (sequential)**

1. ~~Task 1: done — `fetchSets` + `StreakService` + tests.~~
2. Task 2: Create `TodayViewModel` + tests. **Complete in `worktree-s04-task2-today-viewmodel`; merge/integrate when ready.**
3. Task 3: Create `HistoryViewModel` + `SessionDetailViewModel` + tests.
4. Task 4: Replace `RootView` authenticated branch with `TabView` shell (Today/Programs/History).
5. ~~Task 5: done — `TodayView` + mock data + previews.~~
6. ~~Task 6: done — `HistoryView` + `SessionDetailView` + mock data + previews.~~
7. ~~Task 7: done — all Sprint 4 localization keys (Thai + English).~~
8. Task 8: Wire everything together, run tests, smoke test.

---

## Open follow-ups

- [ ] Light/dark visual sweep of `WorkoutSessionView`, `WorkoutExercisePageView`, `SetRowView`, `RestTimerRingView`, `ProgramExerciseEditorView` in Xcode before broad TestFlight.
- [ ] Task 8: map/collapse `TodayViewData` into the real `TodayData` once `TodayViewModel` lands, and wire `onShowPrograms` to tab selection.
- [ ] Task 8: map/collapse `HistoryDisplayData` and `SessionDetailDisplayData` into the real History/Session detail ViewModel data once Task 3 lands.
- [ ] Confirm S05 Settings rows at Task 0 of Sprint 5 before any code lands (weight unit toggle, sign out, app version, privacy placeholder, delete placeholder).

---

## How to resume

1. Read this file.
2. Read `.claude/sprints/S04-today-history/spec.md` for Sprint 4 scope.
3. Read `.claude/sprints/S04-today-history/plan.md` — start at the first unchecked task.
4. Update the `## CURRENT STATUS` block in the sprint plan as you go.
5. Update this file before ending the session.
