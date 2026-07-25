# RPE UX Simplification — Design

**Date:** 2026-07-22
**Status:** Approved. Implementation plan written: `docs/superpowers/plans/2026-07-23-rpe-ux-simplification.md` (not yet executed).
**Author:** Brainstormed with Claude Code

## Context

This is the first of four post-launch features the user wants to add after using
the app for a while:

1. **RPE UX simplification** (this doc)
2. Skip a day in a workout plan (e.g. skip leg day in a Push/Pull/Legs program)
3. Switch to a related exercise mid-workout (e.g. bench press → machine chest press)
   — overlaps with the existing but unspecced roadmap entry **Sprint 9 — Substitute +
   Defer** in `.claude/GYMTRACK.md`
4. Progressive overload advisor sessions — proactively nudge the user when they've
   plateaued at a weight, building on the already-implemented `ProgressiveOverloadEngine`
   and the still-unbuilt `StallDetector` / `DeloadAdvisor` from the Sprint 7 checklist

These four are independent subsystems and are being brainstormed and implemented one
at a time. This document covers only #1. #2–#4 are out of scope here and will each get
their own design doc later.

## Problem

`SetRowView`'s per-set effort input is a raw `Menu` listing 1.0–10.0 in 0.5 increments
(19 items), labeled "RPE" — an acronym that isn't explained anywhere in the app and is
left untranslated even in the Thai locale (`workout.set.header.rpe` is literally "RPE"
in both `en` and `th`). Basic users don't know what RPE means, and some don't want to
record it at all per set.

The app already solved this exact problem once: comeback-mode sessions show a friendly
3-option picker (Easy / Just right / Hard, via the `HowDidThatFeel` enum and
`HowDidThatFeelPicker` sheet) instead of a raw number — but only as a single end-of-exercise
prompt in comeback mode, not as the everyday per-set control.

## Goals

- Replace the per-set raw numeric RPE input with the same plain-language 3-option scale
  already used in comeback mode (Easy / Just right / Hard), applied universally (normal
  and comeback sessions alike).
- Keep the existing per-set frequency — the user explicitly asked to keep logging effort
  per set, just with simpler wording, not to reduce how often it's asked.
- Keep it trivially skippable (a `Clear` option, empty by default) for users who don't
  want to record it at all.
- Make zero changes to the algorithmic consumers of RPE (`ComebackRampService`,
  `ProgressiveOverloadEngine`) — the three new values map directly onto their existing
  thresholds.

## Non-goals

- No change to how RPE is *displayed* in genuinely read-only views (the History list,
  the "last session" reference row in the logger). Those already just print whatever
  number is stored and aren't the friction point.
- No new user preference to hide RPE entirely — the per-set `Clear` option already makes
  it fully optional without adding a new settings surface.
- No change to `ComebackRampService` or `ProgressiveOverloadEngine` thresholds.

**Correction (found while writing the implementation plan):** `SessionDetailView`'s
per-set edit form (`session.set.edit.title`, editing a completed `WorkoutSet` from
History) is *not* read-only — it has its own copy of the same raw 1.0–10.0 `Menu`,
sharing the `workout.set.rpe` / `workout.set.rpe.clear` keys. This is in scope (see
Design §1a below); the "read-only" characterization above applies only to the History
list and the "last session" reference row, not to this edit form.

## Design

### 1. Per-set control (`Gymbros/Presentation/Workout/SetRowView.swift`)

Keep the existing `Menu`-button component, its column width, and its 48pt tap target —
zero layout risk, no changes to `WorkoutSetTableLayout`. Replace only its contents:

- Menu items: Easy / Just right / Hard (each rendered with the same SF Symbol already
  used in `HowDidThatFeelPicker`: `face.smiling` / `checkmark.circle` / `flame`), plus a
  `Clear` item at the bottom (destructive role, same as today).
- Closed-state button: shows the SF Symbol of the selected value once one is picked, or
  a neutral placeholder (current "RPE" text becomes "Feel") when unset.
- Closed-state button gets an explicit `.accessibilityLabel` (e.g. "Feel: Just right" /
  "Feel: not set") since the icon-only closed state has no meaningful default VoiceOver
  text once "RPE 7.5" text is gone.
- Underlying value: `rpe: Double?` unchanged. Selecting the three options sets
  `6.0` / `7.5` / `9.0` respectively (the exact values `HowDidThatFeel` already defines),
  `Clear` sets `nil`.

Column header (`workout.set.header.rpe`, currently literal "RPE" in both locales) is
renamed to a new key `workout.set.header.feel` = "Feel" (en) / "รู้สึก" (th).

### 1a. Same replacement in `SessionDetailView`'s edit-set form

`Gymbros/Presentation/History/SessionDetailView.swift` (the `session.set.edit.title`
form, roughly lines 233–249) has its own raw 1.0–10.0 `Menu`, structured as a `Form`
row rather than a compact table cell (more horizontal room, so it can show full text
labels, not just an icon). Apply the same 3-option-plus-Clear content here, using the
same new localization keys from §3. Closed-state row shows the full label text ("Easy" /
"Just right" / "Hard" / "—" when unset) since a `Form` row has room for it — no icon-only
constraint here like the compact table cell.

### 2. Remove comeback mode's separate feedback sheet

Comeback mode currently shows `HowDidThatFeelPicker` as a sheet at "Finish Exercise,"
which overwrites the `rpe` on every completed set in that exercise with one value
(`WorkoutSessionViewModel.applyFeedback`). Once per-set input uses the same three
values, this becomes redundant and would silently clobber whatever the user already
picked per set.

Remove:
- The `feedbackExerciseId` state, the `.sheet` presentation, and the `isComebackMode`
  branch inside `onFinishExercise` in `WorkoutSessionScreen.swift` — `onFinishExercise`
  always calls `viewModel.finishExercise(programExerciseId:)` directly, comeback or not.
- `WorkoutSessionViewModel.applyFeedback(_:to:)`.
- `HowDidThatFeelPicker` view and its localization keys
  (`workout.comeback.feel.title`, `workout.comeback.feel.skip`), since nothing presents
  it anymore. `HowDidThatFeel` the enum itself stays — its `rpe`/`symbolName`/`titleKey`
  values are reused by the per-set menu (see below).

### 3. Localization

Reuse copy, generalize keys away from the "comeback" namespace since the three
options are no longer comeback-specific:

| New key | en | th | Replaces |
|---|---|---|---|
| `workout.set.feel.easy` | Easy | สบาย | `workout.comeback.feel.easy` |
| `workout.set.feel.just_right` | Just right | พอดี | `workout.comeback.feel.just_right` |
| `workout.set.feel.hard` | Hard | หนัก | `workout.comeback.feel.hard` |
| `workout.set.feel.clear` | Clear | ล้าง | `workout.set.rpe.clear` ("Clear RPE" / "ล้าง RPE") |
| `workout.set.header.feel` | Feel | รู้สึก | `workout.set.header.rpe` ("RPE") |
| `workout.set.feel` (closed-state placeholder) | Feel | รู้สึก | `workout.set.rpe` ("RPE") |

`HowDidThatFeel.titleKey` (`workout.comeback.feel.*`) is repointed to the new
`workout.set.feel.*` keys since it's now used outside comeback mode too. Old keys
(`workout.comeback.feel.easy/just_right/hard`, `workout.comeback.feel.title`,
`workout.comeback.feel.skip`, `workout.set.rpe`, `workout.set.rpe.clear`,
`workout.set.header.rpe`) are removed from `Localizable.xcstrings`, not just orphaned.

### 4. Data model and downstream consumers — unchanged

`WorkoutSet.rpe: Double?` is untouched. Verified against both algorithmic consumers:

- `ComebackRampService.decide`: `6.0` → `< 6.5` → increase 15%; `7.5` → not `< 7.5`,
  is `< 8.5` → hold+rep; `9.0` → not `< 8.5` → decrease 5%. All three land in distinct,
  sensible bands.
- `ProgressiveOverloadEngine`: `6.0` → `≤ 7.0` → +2.5kg; `7.5` → in `[7.5, 8.0]` → hold;
  `9.0` → outside both → no suggestion. All three land in distinct, sensible bands.

No changes needed to either service.

### 5. Edge case: legacy and restored values

Sets logged before this change (already in the DB) or sitting in a pre-upgrade
active-session backup may hold arbitrary values from the old 19-item scale (e.g. `6.5`,
`8.0`). Both edit surfaces (`SetRowView`'s closed-state icon and `SessionDetailView`'s
closed-state label) bucket any stored value to the nearest of the three canonical points
rather than showing a broken/undefined 4th state, via one shared helper function:

```
value <= 6.75            -> Easy
6.75 < value <= 8.25      -> Just right
value > 8.25              -> Hard
```

This bucketing is display-only — it does not rewrite the stored value. If the user then
opens the menu and picks an option, the value snaps to the exact canonical number for
that option, same as normal.

The genuinely read-only views (History list, "last session" reference row) keep
displaying the raw stored number unchanged — they are out of scope (see Non-goals).

## Testing

- `SetRowView` previews and any existing snapshot/unit coverage updated for the new
  menu contents and closed-state rendering (icon vs. placeholder).
- `SessionDetailView`'s edit-set form manually verified for the same new menu contents
  and closed-state label rendering.
- New unit test for the shared legacy-value bucketing function (three boundary cases
  plus the two threshold edges: `6.75`, `8.25`).
- Remove now-dead tests in `WorkoutSessionViewModelTests` that covered
  `applyFeedback` and the comeback feedback sheet.
- `ComebackRampServiceTests` and `ProgressiveOverloadEngineTests` are unaffected and
  should continue passing unmodified — confirms the "zero downstream changes" claim.
- Full test suite + build must pass before this is considered done, per project
  convention (`xcodebuild test` / `xcodebuild build` with `iPhone 17e`).
- Manual smoke: log a set in a normal session using each of the three options and
  Clear; verify a comeback-mode session no longer shows the end-of-exercise sheet and
  that per-set picks still drive the ramp decision on the next comeback session.

## Open follow-ups

- Features #2–#4 listed under Context are not designed yet; each needs its own
  brainstorming pass.
- Whether this becomes a named sprint (e.g. slotted into or alongside Sprint 7) or
  ships as a standalone polish commit is a scheduling decision, not a design one —
  left for the implementation-plan step.
