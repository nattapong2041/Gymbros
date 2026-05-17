# STANDUP — Session Handoff

> Update this file at the start and end of every session (date, HEAD SHA, last-done, next-up, open follow-ups).

---

**Last updated:** 2026-05-18 | HEAD `dde0a8c` | Branch `main` (sprint docs modified, not committed)

---

## Where we are

Phase 1 ("Real Life Works") is ~75% done — Sprints 1–3 complete. Sprint 4 is next. Settings was split into its own Sprint 5; old Sprints 5–13 renumbered to 6–14.

| Sprint | Name | Status |
|--------|------|--------|
| S01 | Foundation + Data | complete |
| S02 | Custom Program Builder | complete |
| S03 | Logger + Timer | complete |
| **S04** | **Today + History + Navigation + Anti-Guilt UX** | **next up** |
| S05 | Settings | not started |
| S06 | Next Best Session v1 / Smart Comeback | not started |

---

## Last session did

- Task 0 (Spec Lock) for Sprint 4: identified and locked 8 ambiguities in `spec.md` and `plan.md`.
  - Locked ViewModel init signatures (protocol-typed repo params, nil-default → concrete fallback).
  - Added `fetchSets` to `WorkoutRepositoryProviding` protocol (not just the concrete class).
  - Made `SessionDetailData.exerciseLookup` non-optional; added `ExerciseRepositoryProviding` injection; added `session.exercise.unknown` fallback key.
  - History day-name resolution: `HistoryData` gains `dayNames: [UUID: String]`; `HistoryViewModel` also fetches all programs; `history.session.custom` fallback key.
  - Next-day fallback rule for nil/stale `programDayId` in TodayViewModel.
  - StreakService must use `Calendar(identifier: .iso8601)` — never `Calendar.current`.
  - `fetchActive()` is fully hydrated; Tasks 2/5 use `nextDay.exercises` directly.
  - WorkoutSessionScreen presentation: `.navigationDestination(item:)` push (not modal) — matches `DayBuilderView`.
- All 7 Task 0 checkboxes marked `[x]`.

---

## Next up

**Sprint 4 — Tasks 1–7 (can run in parallel), then Task 8 (sequential)**

1. Task 1: Add `fetchSets` to protocol+class, create `StreakService`, write tests.
2. Task 2: Create `TodayViewModel` + tests.
3. Task 3: Create `HistoryViewModel` + `SessionDetailViewModel` + tests.
4. Task 4: Replace `RootView` authenticated branch with `TabView` shell (Today/Programs/History).
5. Task 5: Build `TodayView` + mock data + previews.
6. Task 6: Build `HistoryView` + `SessionDetailView` + mock data + previews.
7. Task 7: Add all Sprint 4 localization keys (Thai + English) to `Localizable.xcstrings`.
8. Task 8: Wire everything together, run tests, smoke test.

---

## Open follow-ups

- [ ] Light/dark visual sweep of `WorkoutSessionView`, `WorkoutExercisePageView`, `SetRowView`, `RestTimerRingView`, `ProgramExerciseEditorView` in Xcode before broad TestFlight.
- [ ] Confirm S05 Settings rows at Task 0 of Sprint 5 before any code lands (weight unit toggle, sign out, app version, privacy placeholder, delete placeholder).

---

## How to resume

1. Read this file.
2. Read `.claude/sprints/S04-today-history/spec.md` for Sprint 4 scope.
3. Read `.claude/sprints/S04-today-history/plan.md` — start at the first unchecked task.
4. Update the `## CURRENT STATUS` block in the sprint plan as you go.
5. Update this file before ending the session.
