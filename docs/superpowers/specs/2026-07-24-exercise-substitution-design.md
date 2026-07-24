# Exercise Substitution ("Substitute") — Design

> Status: **Approved** 2026-07-24. Resumes and finalizes the outline discussed
> 2026-07-23 (see `.claude/GYMTRACK.md` §9 Sprint 6.1, item 5, and §10 "Substitute
> Ranker") which was never formally confirmed before that session moved into a
> roadmap reorganization.

## Problem

A user mid-workout hits a real-life obstacle — bench is taken, a machine is
broken — and today has no in-app way to keep going without either waiting or
improvising an untracked substitute exercise outside the app. This is pain
point #6 in `.claude/GYMTRACK.md` §2 ("Gym is crowded").

## Scope

Session-scoped only. Swapping an exercise mid-workout never touches
`ProgramExercise` or `Program` — the user's program stays exactly as designed;
only *this session's* remaining sets move to a different exercise. This is
deliberately narrow: it does not cover "Defer" (reordering position in the
session — separate flow, still unspecced, stays at Sprint 9) or "Injury
Substitution" (different trigger — pain, not availability — needs
medically-conservative copy and its own filtering logic; stays at Sprint 10).

Ships **free**, no entitlement/paywall check. `GYMTRACK.md` §12's monetization
table lists "substitute/defer intelligence" under a future Pro tier, but no
subscription infrastructure (StoreKit/RevenueCat/entitlements) exists in the
app yet — building a paywall for one feature ahead of that infrastructure
would be scope creep. Revisit which features are Pro-gated once Sprint 12
(RevenueCat + Paywall) actually exists.

## UX Flow

**Entry point:** A "Swap exercise" button in the exercise page header
(`WorkoutExercisePageView.exerciseHeader`), visible whenever the exercise
isn't finished (`section.isFinished == false`) — including mid-exercise,
after some sets are already logged. The button stays available after a swap
too, so the user can swap again (to a third exercise, or back to the
original) as many times as needed in one exercise.

**Ranked-candidates sheet:** Tapping it loads and presents a sheet listing
exercises that share the same `movementPattern` + `primaryMuscle` as whatever
exercise is currently active for that slot, excluding the currently-active
exercise itself (same "exclude what's currently shown" rule already applied
to Skip a Day's day picker, S06.1 item 2). Each row shows: name · equipment ·
last weight if the user has logged it before (e.g. "Machine Chest Press ·
Machine · last: 40kg"; omitted if never logged). Sort order: different
equipment from the original first, then exercises the user has history with,
then alphabetical (stable tie-break).

If the filtered candidate list has fewer than 3 results, the sheet also shows
a "Browse all exercises" link that opens the existing `ExercisePickerView`
(reused as-is from Program Builder — search + muscle/equipment/pattern
filters, no changes needed) as the unranked fallback.

**Picking a candidate:** Every not-yet-completed set in that exercise slot
switches to the picked exercise: its `exerciseId` is reassigned and its
weight is cleared/re-prefilled from the new exercise's last logged weight
(target reps/rest are left untouched — the *volume* plan stays intact, only
the movement/equipment changes). Sets already marked complete are frozen —
they keep their original exercise identity, weight, and reps exactly as
logged. The header updates to show the new exercise's name.

**Set table display:** Stays a single continuous list (set 1, 2, 3…) rather
than splitting into per-exercise blocks. Any row whose `exerciseId` differs
from the exercise currently shown in the header gets a small inline origin
marker (`SubstituteOriginBadge`, e.g. "↩ Bench") so the user can see what a
given completed set was actually performed as.

**Weight suggestion:** History-based only — the user's last logged weight for
that exercise via the existing `WorkoutRepository.fetchLastLoggedSet(exerciseId:before:)`
lookup, already used for `resolveDefaultWeights`. No new query type. If the
user has never logged that exercise before, the weight starts blank, same as
logging any new exercise for the first time. The previously-scoped
"biomechanics ratio" fallback (estimating weight for a never-tried exercise
via a hardcoded strength-ratio table) is explicitly rejected — the app has no
real data source for those ratios; inventing them was flagged as a smell
during the original 2026-07-23 discussion and is not part of this design.

## Ranking Algorithm — `SubstituteRanker`

Pure Swift, no I/O, lives at `Data/Services/SubstituteRanker.swift` (matches
the architecture rule that services take data in and return suggestions out).

```text
filter(original, library):
  library.filter {
    $0.id != original.id
    && $0.movementPattern == original.movementPattern
    && $0.primaryMuscle == original.primaryMuscle
  }

rank(original, candidates, lastLoggedWeightsKg):
  candidates
    .map { SubstituteCandidate(exercise: $0, lastLoggedWeightKg: lastLoggedWeightsKg[$0.id]) }
    .sorted by:
      1. different equipment from original ranks above same equipment
      2. has logged history (lastLoggedWeightKg != nil) ranks above no history
      3. exercise name, alphabetical (stable fallback)
```

**Simplification from the original 2026-07-23 sketch, made deliberately:**
"familiarity" was originally described as "historical set count." There is no
existing count query, and adding one purely to break a tie between two
already-filtered, already-narrow candidates is not worth a new repository
method. This design uses a boolean "has the user logged this before" signal
instead — sourced from the same `fetchLastLoggedSet` call already needed to
show the "last: Xkg" hint in the row and to prefill the weight after picking.
One fetch serves both the ranking tie-break and the display value.

**Where the exercise library and weight lookups come from:** `WorkoutSessionViewModel`
already loads the full exercise library into `exerciseLookup` at session start
(`exerciseRepository.fetchAll()`), so `filter` runs entirely in memory — no new
query. Weight lookups run as a sequential loop over the (typically small,
single-digit) filtered candidate list, calling the existing
`fetchLastLoggedSet(exerciseId:before:)` once per candidate — same sequential-await
style already used in `buildLastSessionReferences`, not a new concurrency
pattern.

## Data Model Changes

- `WorkoutSetRowState.exerciseId`: change from `let` to `var`. This is the
  only structural model change — `WorkoutSet.exerciseId` already lives
  per-set server-side (confirmed via `LastSessionLookupService`'s existing
  same-programExercise / same-exercise fallback), so already-uploaded
  completed sets are entirely unaffected by an in-session row mutation.
- `WorkoutExerciseSection.exercise` (already `var`, already `Exercise?`): no
  new field. Mutating it in place to the substitute exercise is exactly what
  drives the header display, and is safe because every other computation
  that needs the *original* planned exercise (last-session reference,
  comeback baseline, overload/stall tracking) already keys off
  `programExercise.id` / `programExercise.exerciseId`, not `section.exercise`
  — confirmed by reading `buildLastSessionReferences`,
  `applyingBaselineReferences`, and `resolveDefaultWeights`.
- `WorkoutExerciseSection.defaultWeight` (already exists): updated to the
  substitute's suggested weight on swap, so any set added later
  (`addSet(after:)`) after the swap carries forward a sensible value.
- `addSet(after:)`: currently hardcodes new rows' `exerciseId` to
  `programExercise.exerciseId`. Changed to use the section's current active
  exercise (`section.exercise?.id ?? programExercise.exerciseId`) so sets
  added after a swap also get the substitute's identity.
- No backup/restore schema changes: `ActiveSessionBackup` already encodes
  `WorkoutExerciseSection` (including `exercise`) and `WorkoutSetRowState`
  (including `exerciseId`) as they stand today — a swap changing their values
  in place round-trips through the existing backup format unchanged.

New (session-local, not persisted beyond the view model's own state):

```swift
struct SubstituteCandidate: Identifiable, Equatable {
    var id: UUID { exercise.id }
    let exercise: Exercise
    let lastLoggedWeightKg: Double?
}

struct SubstitutePrompt: Identifiable {
    let id = UUID()
    let programExerciseId: UUID
    let originalExercise: Exercise
    let candidates: [SubstituteCandidate]
    let showsBrowseAllFallback: Bool
}
```

`WorkoutSessionViewModel` gains `var substitutePrompt: SubstitutePrompt?`
(drives a `.sheet(item:)`, same pattern as `overloadOutcomePrompt`), plus:

- `presentSubstituteOptions(programExerciseId: UUID) async` — builds and sets
  `substitutePrompt`.
- `selectSubstitute(_ exercise: Exercise) async` — performs the swap
  described above, tracks analytics, clears `substitutePrompt`, saves backup.

## UI Components

- `SubstituteCandidateSheet` (new view): medium-detent sheet, Cancel toolbar
  action (mirrors `FeelPickerSheet`'s sheet chrome convention). Lists ranked
  candidates as rows (reusing `EquipmentIconView` for the equipment icon);
  tapping a row calls the selection closure and dismisses. Shows a "Browse
  all exercises" row/link at the bottom only when `showsBrowseAllFallback` is
  true, which presents `ExercisePickerView` (existing, unmodified) as a
  nested sheet with the same selection closure.
- `SubstituteOriginBadge` (new view): small capsule badge, same visual family
  as `EasingBackBadge`/`OverloadSuggestionBadge` (`.caption.weight(.semibold)`,
  capsule background, `arrow.uturn.left` icon), showing the origin exercise's
  name. Rendered inline per-row in `WorkoutExercisePageView`'s set list for
  any row whose `exerciseId` differs from `section.exercise?.id`.
- `WorkoutExercisePageView.exerciseHeader`: gains a "Swap exercise" button
  (icon `arrow.triangle.2.circlepath`), hidden when `section.isFinished`.
- Wiring follows the existing `WorkoutSessionScreen` → `WorkoutSessionView` →
  `WorkoutExercisePageView` action-closure chain (`onSwapExercise: (UUID) ->
  Void`, mirroring `onFinishExercise`), with the sheet itself presented at the
  `WorkoutSessionScreen` level via `.sheet(item:)`, matching how
  `overloadOutcomePrompt` is already presented as an alert at that level.

## Analytics

Two new no-payload `AnalyticsEvent` cases, matching the existing convention
(all current cases are payload-free) and the event names already documented
in `GYMTRACK.md` §13's "Real-Life Adaptation Metrics":

- `.exerciseSubstituted` — tracked once per successful swap.
- `.substituteRankSelected` — tracked alongside it (kept as a second discrete
  event rather than an associated value, consistent with how every other
  `AnalyticsEvent` case is a plain marker today).

## Out of Scope

- Paywall/entitlement gating (see Scope above).
- Defer (Sprint 9) and Injury Substitution (Sprint 10) — different flows,
  different triggers, unbuilt.
- Biomechanics-ratio weight estimation for never-tried substitutes.
- Historical-set-count familiarity ranking (simplified to a boolean
  has-history signal — see Ranking Algorithm above).
- A gym-equipment-inventory feature ("mark bench unavailable") — ranking
  approximates this by preferring different equipment, since the app has no
  actual equipment-availability data source.
- Any change to `ProgramExercise`/`Program` — swaps are 100% session-local.
- Multiple simultaneous exercises sharing one slot (supersets) — Substitute
  applies to one `WorkoutExerciseSection` at a time, same granularity the
  logger already uses everywhere else.
