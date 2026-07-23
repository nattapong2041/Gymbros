# Skip a Day (One-Off Day Swap) — Design

**Date:** 2026-07-23
**Status:** Approved, pending implementation plan
**Author:** Brainstormed with Claude Code

## Context

Second of four post-launch features requested after using the app hands-on (see
`.claude/GYMTRACK.md` → "Post-Launch Feature Backlog (gathered 2026-07-23)" and
`docs/superpowers/specs/2026-07-22-rpe-ux-simplification-design.md` for #1 of the four,
already designed and planned separately).

## Problem

`TodayView` always recommends exactly one day — whatever `NextBestSessionEngine.nextDay`
computes next in the program's rotation. There is no way for the user to say "not that
one today" and start a different day from their own program instead (e.g. skip leg day
in a Push/Pull/Legs program because the squat rack is taken, or they just don't feel
like it). The only existing way to start a workout for a specific `ProgramDay` is
through `TodayView`'s single recommended day, or incidentally through the Day Builder's
internal test-run flow (`DayBuilderView`, an editing context, not a user-facing picker).

## Goal

Let the user swap today's recommended day for any other day in their active program,
for this session only, without touching the program's structure or the rotation logic.

## Non-goals

- Permanently removing/disabling a day from the program (that's a Program Builder /
  program-editing feature, out of scope here — see the "Both" option considered and
  rejected during brainstorming in favor of one-off-only for this pass).
- Any change to `NextBestSessionEngine`, `SmartSessionAdvisor`, `ComebackRampService`,
  or `ProgressiveOverloadEngine`.
- Any new persisted "rotation pointer" state — see Design below for why none is needed.

## Design

### Why this is a small, view-local change

Two things confirmed by reading the current implementation make this feature much
smaller than it first looks:

1. **Rotation is self-correcting, not a stored pointer.**
   `NextBestSessionEngine.nextDay(from:recentHistory:)` always derives "what's next" by
   finding the most recently *completed* session's `programDayId` in the program's
   `dayOrder`-sorted days and returning the following one (wrapping via `%`). It reads
   real history, not a separate rotation counter. So once a swapped-to session is
   actually logged, the next recommendation naturally continues from there — no new
   state to write or reset.

2. **Comeback adjustments are already program-wide, not day-scoped.**
   `NextBestSessionEngine.recommend` builds `trackedExercises` from
   `program.days.flatMap(\.exercises)` — every exercise in every day, not just the
   recommended day's exercises — and populates `TodayRecommendation.adjustments` (keyed
   by `programExercise.id`) across all of them. So a comeback-mode user who swaps to a
   different day still gets correct ramp-down weights for that day's exercises; the same
   `TodayRecommendation` object already has what it needs.

3. `WorkoutSessionScreen(programDayId: UUID, ...)` already accepts any day id directly —
   the session-starting mechanism itself needs zero changes.

Combined, the feature is: give the user a way to pick a different `programDayId` before
starting, on `TodayView` alone.

### UI

`TodayView` (`Gymbros/Presentation/Today/TodayView.swift`) gains:

- `@State private var selectedDay: ProgramDay?`, reset implicitly whenever the view's
  identity resets (no explicit reset logic needed — see Edge cases).
- A "Change day" secondary button placed next to the existing Start CTA. Shown only
  when `activeProgram.days.count > 1` (see Edge cases for when it's hidden).
- Tapping it opens a `Menu` (same pattern already used for pickers elsewhere in the app,
  e.g. the RPE feel picker) listing `activeProgram.days.sorted { $0.dayOrder < $1.dayOrder }`,
  **excluding** the currently-recommended `nextDay` (picking the already-recommended day
  would be redundant with just tapping Start). Each item shows the day's own `name`
  (user-entered free text, already displayed elsewhere on Today — no new localization
  needed for day names themselves).
- Picking a day sets `selectedDay`. The Start CTA then passes
  `programDayId: (selectedDay ?? nextDay)?.id` into `WorkoutSessionScreen` instead of
  always `nextDay?.id`. `WorkoutSessionScreen`'s `recommendation: TodayRecommendation`
  parameter is passed through completely unchanged — no recomputation, since adjustments
  already cover every day (see above).

### Localization

One new key:

| Key | en | th |
|---|---|---|
| `today.change_day.button` | Change day | เปลี่ยนวัน |

### Edge cases

- **Program has only one day:** "Change day" button is hidden (`activeProgram.days.count > 1`
  guards it) — there is nothing to swap to.
- **No active program / no recommendation:** Already covered by Today's existing
  empty-state handling (`nextDay == nil`); the button simply doesn't render since it's
  conditioned on having a program with days.
- **Swapped-to exercise has no comeback baseline data** (e.g. never logged before the
  gap): degrades the same way any exercise without history already does today —
  `adjustments[programExercise.id]` is `nil` or has a `nil` baseline, and the session
  falls back to normal (unadjusted) treatment for that exercise. Not a new failure mode.
- **Stale `selectedDay` across a background/foreground cycle without the view being
  recreated:** left as-is intentionally — if the user picked a day and didn't start yet,
  keeping that pick when they return to the app is the expected behavior, not a bug.

## Testing

- No `NextBestSessionEngine`, `TodayViewModel`, or `WorkoutSessionViewModel` changes are
  needed, so no new or modified unit tests are expected — this is a `TodayView`-local
  `@State` addition.
- Build must succeed (`xcodebuild build` with `iPhone 17e`), consistent with how other
  View-only changes in this project are verified (Views aren't unit-tested; Services are
  100% unit-tested per project convention).
- Manual smoke:
  1. On a program with 2+ days, confirm "Change day" appears next to Start and lists
     every day except the recommended one.
  2. Pick a different day, tap Start, confirm the session opens for the picked day (not
     the originally recommended one).
  3. Finish that session, return to Today, confirm the next recommendation follows the
     day the user actually completed, not the originally-skipped day.
  4. Force a comeback scenario (per the existing S06 smoke procedure), swap to a
     different day, confirm that day's exercises still show adjusted (ramped-down)
     weights, not full baseline weights.
  5. On a program with only one day, confirm "Change day" does not appear.

## Open follow-ups

- Feature #3 (progressive overload advisor sessions) and the permanent
  day-removal case explicitly deferred under Non-goals are not designed yet.
