# STANDUP — Session Handoff

> Update this file at the start and end of every session (date, HEAD SHA, last-done, next-up, open follow-ups).

---

**Last updated:** 2026-05-18 | HEAD `dde0a8c` | Branch `main` (clean)

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

- Created `.claude/sprints/S04-today-history/spec.md` and `plan.md` — Sprint 4 spec: Today + History + Navigation + Anti-Guilt UX, 8 tasks (Tasks 0–8).
- Created `.claude/sprints/S05-settings/spec.md` and `plan.md` — Sprint 5 spec: Settings tab, weight-unit toggle, Sign Out, placeholders.
- Renumbered `GYMTRACK.md` doc-wide: Settings inserted as Sprint 5, old Sprints 5–13 → 6–14, Sprint Tracking table updated (14 rows), all cross-references updated.
- Added 2026-05-17 decision log entry in GYMTRACK.md recording the Settings split and renumber.

---

## Next up

**Sprint 4 — Today + History + Navigation + Anti-Guilt UX**

1. Read `.claude/sprints/S04-today-history/spec.md` for full scope.
2. Start at Task 0 (Spec Lock) in `.claude/sprints/S04-today-history/plan.md`.
3. Implement task-by-task, marking each checkbox `[x]` as done.
4. Note: Settings tab is **not** part of Sprint 4 — it is Sprint 5.

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
