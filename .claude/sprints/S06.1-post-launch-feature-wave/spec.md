# Sprint 6.1 — Post-Launch Feature Wave

> Detailed implementation spec for coding agents.
> Reference: `.claude/GYMTRACK.md` §9 Sprint 6.1, plus the five individual design docs this
> sprint consolidates:
> - `docs/superpowers/specs/2026-07-22-rpe-ux-simplification-design.md`
> - `docs/superpowers/specs/2026-07-23-skip-a-day-design.md`
> - `docs/superpowers/specs/2026-07-23-training-phase-setting-design.md`
> - `docs/superpowers/specs/2026-07-23-progressive-overload-advisor-design.md`
> - `docs/superpowers/specs/2026-07-24-exercise-substitution-design.md`

---

## Overview

**Goal:** Ship five independent, already-approved post-launch features gathered from
real hands-on use after Sprint 6: (1) replace the raw numeric RPE picker with a plain
Easy/Just right/Hard scale everywhere it appears, (2) let the user start a different day
than the one recommended for this session only, (3) let the user record a training phase
(bulk/cut/maintain) in Settings, (4) proactively surface a "same weight for a while"
card on Today when a tracked exercise has plateaued, gated on that training phase so a
cutting/maintaining user is never nagged to add weight, and (5) let the user swap an
exercise mid-workout for a ranked related exercise when the original is unavailable
(crowded gym, broken machine), without breaking the session.

**Primary acceptance test:** Log a set choosing "Just right" instead of a raw RPE number,
in both the live logger and the History edit-set form. On Today, tap "Change day" and
start a different day than the one recommended; the workout opens for the picked day.
In Settings, set training phase to "Building muscle." Log the same top-set weight for an
exercise across 4 consecutive sessions at RPE ≤ 8.0 → Today shows an
`OverloadAdvisorCardView` for that exercise with "Try it next time" / "Not now" actions.
Switch training phase to "Losing weight" → the card stops appearing for that exercise.
Mid-workout, tap "Swap exercise," pick a ranked candidate, and confirm the remaining sets
in that slot switch to it while already-completed sets stay unchanged.

**Effort estimate:** Medium-Complex (combined). Individually: RPE is Simple (UI-only,
plan already exists), Skip a Day is Simple (`TodayView`-local `@State`), Training Phase
is Simple (one column + one Settings row, needs a migration), Progressive Overload
Advisor is Medium (one new pure service, one new local store, one new card,
`TodayViewModel` wiring), Substitute is Medium (one new pure service, one new sheet,
`WorkoutSessionViewModel` wiring, one small model mutability change).

**Dependencies:** Sprints S01–S06 complete (S06 manual smoke still pending, tracked
separately — does not block this sprint). Reuses `HowDidThatFeel`, `SetRowView`,
`SessionDetailView`'s `EditSetSheet`, `TodayView`/`TodayViewModel`, `ComebackCardView` (as
a UI pattern to mirror), `ProfileRepositoryProviding`, `SettingsViewModel`,
`ProgramRepositoryProviding.updateProgramExercise(_:)`, `ProgressiveOverloadEngine`
(reuses its `weightIncrementKg` constant only — no logic changes), `WorkoutSessionViewModel`'s
`exerciseLookup` and `fetchLastLoggedSet`, `ExercisePickerView` (reused unmodified), and
the `AppError` / `ViewState` pipeline throughout.

**Build order within this sprint** (per the 2026-07-23/24 GYMTRACK.md decision log): RPE UX
Simplification and Skip a Day first (both independent, no dependencies on each other or
on anything else in this sprint). Training Phase Setting next (foundational — nothing
else in this sprint depends on it, but the Progressive Overload Advisor consumes its
`Profile.trainingPhase` field). Progressive Overload Advisor next (depends on Training
Phase Setting shipping first). Substitute last — independent of the other four (touches
`WorkoutSessionViewModel`/`WorkoutExercisePageView`, not `TodayView`/`Settings`), ordered
last only because its own approval pass landed a day after the other four.

---

## 1. Requirements

### Must Have

```text
--- 1. RPE UX SIMPLIFICATION ---
☐ Replace SetRowView's per-set raw 1.0-10.0 RPE Menu with the existing Easy/Just
  right/Hard scale (reusing HowDidThatFeel), plus a Clear option
☐ Same replacement in SessionDetailView's EditSetSheet (History's edit-a-past-set form)
☐ HowDidThatFeel.nearest(to:) bucketing helper for legacy/restored raw RPE values
  (boundaries: <=6.75 -> easy, <=8.25 -> justRight, else -> hard)
☐ Remove comeback mode's now-redundant end-of-exercise HowDidThatFeelPicker sheet and
  WorkoutSessionViewModel.applyFeedback/hasCompletedSets — per-set input already
  captures the same three values everywhere, so the separate sheet would silently
  clobber whatever the user already picked per set
☐ Localization: workout.set.feel.* keys replace workout.set.rpe* /
  workout.comeback.feel.* (old keys removed, not orphaned)
☐ Zero changes to ComebackRampService or ProgressiveOverloadEngine — the three RPE
  values (6.0/7.5/9.0) already land in distinct, sensible bands in both services

--- 2. SKIP A DAY (ONE-OFF DAY SWAP) ---
☐ "Change day" control on TodayView, shown whenever the active program has a day other
  than the currently-recommended one to switch to
☐ Menu lists activeProgram.days (sorted by dayOrder) excluding the originally
  recommended nextDay
☐ Picking a day re-renders the existing card (comeback or normal) using the picked
  day's data — same render path as the originally recommended day, just a different
  ProgramDay passed in
☐ WorkoutSessionScreen receives the picked day's id; the TodayRecommendation object is
  passed through completely unchanged (comeback adjustments are already keyed by
  programExerciseId across the whole program, not just one day)
☐ No NextBestSessionEngine, SmartSessionAdvisor, ComebackRampService, or
  ProgressiveOverloadEngine changes
☐ No new persisted "rotation pointer" — rotation is already self-correcting from history

--- 3. TRAINING PHASE SETTING ---
☐ Wire up the existing but completely unused Model/Enums/TrainingPhase.swift
  (bulk/cut/maintain)
☐ Add Profile.trainingPhase: TrainingPhase? (nilable, matching goal's optionality)
☐ Supabase migration adding nullable profiles.training_phase text column — NEEDS
  EXPLICIT USER APPROVAL AT IMPLEMENTATION TIME per CLAUDE.md "Data Safety and Approval"
☐ Settings row mirroring the existing weight-unit toggle pattern exactly: SettingsData
  gains trainingPhase, SettingsViewModel gains updateTrainingPhase(_:), SettingsView
  gains a Menu/Picker row
☐ User-facing copy: Building muscle / Losing weight / Maintaining (raw case names
  bulk/cut/maintain are never shown)
☐ Zero behavior change anywhere else yet — no feature reads this value until #4 below

--- 4. PROGRESSIVE OVERLOAD ADVISOR ---
☐ StallDetector: same top-set weight across 4 consecutive qualifying sessions for an
  exercise, with no session among those 4 recording an RPE above 8.0 on that top set
  (missing/nil RPE does not block detection)
☐ OverloadAdvisorCardView on Today: normal mode only (never alongside the comeback
  card — the two modes are already mutually exclusive), one exercise at a time, scoped
  to today's recommended day only, first stalled exercise in the day's exercise order
☐ Suppressed entirely when profile.trainingPhase is .cut or .maintain (nil or .bulk
  shows it) — a deliberate manual escape hatch, not diet detection
☐ "Try it next time" updates that ProgramExercise.targetWeight to
  currentWeight + ProgressiveOverloadEngine.weightIncrementKg (2.5kg) — reuses the
  existing pre-fill mechanism, no new plumbing
☐ "Not now" snoozes that programExerciseId's stall prompt for 14 days via a new
  local-only, UserDefaults-backed OverloadAdvisorSnoozeStore
☐ TodayViewModel now fetches recent sets on normal days too (previously S06 skipped
  this fetch entirely on normal days) — bounded to today's recommended day's exercises,
  last 4 completed sessions, not an open-ended history pull
☐ Zero changes to ProgressiveOverloadEngine, SmartSessionAdvisor, or ComebackRampService

--- 5. SUBSTITUTE (MID-WORKOUT EXERCISE SWAP) ---
☐ "Swap exercise" button in the exercise page header, visible whenever
  `section.isFinished == false` (including mid-exercise after sets are already logged);
  stays available after a swap so the user can re-swap any number of times
☐ SubstituteRanker (new pure service): filters the already-loaded exercise library to
  same movementPattern + primaryMuscle, excluding the currently-active exercise; ranks
  by different-equipment-from-original first, then has-logged-history, then alphabetical
☐ SubstituteCandidateSheet: ranked rows (name · equipment · last weight if known); shows
  a "Browse all exercises" fallback (reusing the existing ExercisePickerView unmodified)
  when the ranked list has fewer than 3 results
☐ On selection: every not-yet-completed WorkoutSetRowState in that exercise slot gets
  the substitute's exerciseId and a re-prefilled weight (from
  fetchLastLoggedSet(exerciseId:before:), same lookup already used elsewhere); target
  reps/rest are untouched. Already-completed sets are frozen exactly as logged.
  WorkoutSetRowState.exerciseId changes from `let` to `var` to support this — the only
  model change, no schema/backup-format change
☐ SubstituteOriginBadge renders inline on any set row whose exerciseId differs from the
  exercise currently shown in the header — no new field, derived from existing state
☐ addSet(after:) updated to tag new rows with the section's current active exercise
  (`section.exercise?.id`) instead of always `programExercise.exerciseId`
☐ No ProgramExercise/Program changes — 100% session-local
☐ Ships free, no paywall/entitlement check (no subscription infrastructure exists yet)
☐ Analytics: `.exerciseSubstituted`, `.substituteRankSelected` (no-payload, matching
  every other existing AnalyticsEvent case)

--- ALL FIVE ---
☐ All visible strings localized in Thai and English
☐ All errors flow through AppError / ViewState
☐ Build + full test suite pass on iPhone 17 simulator (this machine has no iPhone 17e
  simulator installed, per STANDUP.md's 2026-07-24 environment note; use iPhone 17)
```

### Out of Scope

```text
✗ Defer (Sprint 9) and Injury Substitution (Sprint 10) — different flows/triggers from
  Substitute, still unspecced, not part of this sprint
✗ Biomechanics-ratio weight estimation for never-tried substitutes — no real data
  source exists in the app; rejected during the 2026-07-23/24 design discussion
✗ Historical-set-count familiarity ranking — simplified to a boolean has-history signal
  (see design doc); no new count query added
✗ Gym-equipment-inventory ("mark X unavailable") — the app has no such data source;
  ranking approximates this by preferring different equipment instead
✗ Substitute paywall/entitlement gating — no subscription infrastructure exists yet
  (Sprint 12); revisit once it does
✗ DeloadAdvisor — a plateau caused by grinding near failure every session is a
  different signal (back off, don't add weight) from what StallDetector detects;
  explicitly deferred, same shape as StallDetector but opposite trigger
✗ Onboarding wiring for training phase (Sprint 7 doesn't exist yet; Settings is the
  only place to set profile preferences today)
✗ Merging/reconciling TrainingPhase with the existing Profile.goal field — they are
  complementary, not overlapping (goal = long-term aspiration, trainingPhase =
  short-term nutritional cycle)
✗ Actual nutrition/calorie tracking — trainingPhase is a single self-reported enum
✗ Cross-device sync for the overload-advisor snooze state (local UserDefaults only)
✗ Permanently removing/disabling a day from the program (Program Builder feature)
✗ Positive reinforcement copy for .cut phase (e.g. affirming held-strength messaging) —
  deliberately deferred; simplest correct (silent) behavior first
```

---

## 2. Existing Foundation To Reuse

```text
Gymbros/Data/Services/HowDidThatFeel.swift                enum + rpe/symbolName/titleKey
Gymbros/Presentation/Workout/SetRowView.swift              per-set RPE Menu (to replace)
Gymbros/Presentation/History/SessionDetailView.swift       EditSetSheet's own RPE Menu
Gymbros/Presentation/Workout/WorkoutSessionScreen.swift    HowDidThatFeelPicker sheet (to remove)
Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift applyFeedback/hasCompletedSets (to remove)
Gymbros/Presentation/Today/TodayView.swift                 successState/comebackCard/nextWorkoutCard
Gymbros/Presentation/Today/TodayViewModel.swift             fetch()/fetchBudgetedSets()
Gymbros/Presentation/Today/Components/ComebackCardView.swift  UI pattern to mirror for the overload card
Gymbros/Data/Services/NextBestSessionEngine.swift           TodayRecommendation, ExerciseAdjustment (untouched)
Gymbros/Data/Services/ProgressiveOverloadEngine.swift       weightIncrementKg = 2.5 (reused, untouched)
Gymbros/Data/Services/RestTimerNotificationScheduler.swift  UserDefaults-backed store pattern to mirror
Gymbros/Model/Profile.swift                                 gains trainingPhase
Gymbros/Model/Enums/TrainingPhase.swift                     already exists, unused until now
Gymbros/Model/ProgramExercise.swift / ProgramDay.swift       targetWeight, dayOrder, exerciseOrder
Gymbros/Data/Repository/ProfileRepository.swift              fetchCurrentProfile/updateProfile
Gymbros/Data/Repository/ProgramRepository.swift               updateProgramExercise(_:)
Gymbros/Presentation/Settings/SettingsViewModel.swift        updateWeightUnit(_:) pattern to mirror
Gymbros/Presentation/Settings/SettingsView.swift             weight-unit row pattern to mirror
Gymbros/Core/AppPreferences.swift                            environment-injected weight unit
Gymbros/Core/ErrorHandling/AppError.swift / ViewState.swift / ErrorMapper.swift
Gymbros/Resources/Localizable.xcstrings                      alphabetically-sorted key catalog
supabase/migrations/2026-05-11_program_exercises_target_weight.sql  migration file convention
Gymbros/Presentation/Workout/WorkoutExercisePageView.swift    exerciseHeader (Swap button lands here)
Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift    exerciseLookup, addSet(after:), formatWeight(_:)
Gymbros/Data/Repository/WorkoutRepository.swift               fetchLastLoggedSet(exerciseId:before:) (reused, unmodified)
Gymbros/Data/Services/LastSessionLookupService.swift          same-exercise history-matching pattern to mirror
Gymbros/Presentation/Programs/ExercisePickerView.swift        reused unmodified as the browse-all fallback
Gymbros/Presentation/Programs/EquipmentIconView.swift         reused for candidate-row equipment icons
Gymbros/Presentation/Workout/Components/EasingBackBadge.swift  visual pattern for SubstituteOriginBadge
Gymbros/Presentation/Workout/Components/FeelPickerSheet.swift  sheet chrome pattern to mirror
Gymbros/Presentation/Workout/WorkoutSessionScreen.swift        overloadOutcomePrompt item-sheet pattern to mirror
Gymbros/Data/Services/Analytics/AnalyticsTracking.swift        AnalyticsEvent enum (gains 2 cases)
```

---

## 2.1 Spec Lock Decisions

The implementation plan (`plan.md`) locks these before work starts:

1. **RPE:** implemented exactly as already written and verified against the current
   codebase in `docs/superpowers/plans/2026-07-23-rpe-ux-simplification.md`. That plan's
   6 tasks are folded into this sprint's plan verbatim (renumbered), since it was already
   checked line-for-line against the current source files.

2. **Skip a Day placement:** the design doc says the "Change day" control sits "next to
   the Start CTA," but the Start CTA lives inside two different child views
   (`ComebackCardView` and the private `nextWorkoutCard` helper). Rather than threading a
   new parameter into `ComebackCardView`'s public API, the control is rendered as its own
   row in `TodayView.successState`, directly above whichever card is about to render.
   Both `comebackCard(data:nextDay:)` and `nextWorkoutCard(data:nextDay:)` are called with
   `selectedDay ?? nextDay` instead of always `nextDay` — since both functions already
   render whatever `ProgramDay` they're given (name, exercise preview, and the
   `WorkoutLaunchRoute` used to start the session), swapping the input is sufficient:
   no internal logic in either function needs to change.

3. **Skip a Day exclusion rule:** the menu always excludes the *originally recommended*
   `nextDay`, not whatever is currently selected. This matches "picking the
   already-recommended day would be redundant with just tapping Start" and means the
   list of alternatives never becomes empty as a side effect of a previous pick.

4. **Training phase migration timing:** Task 11 in the plan (the SQL migration) is a
   hard stop — the plan instructs the implementing agent to present the exact SQL to the
   user and wait for explicit confirmation before running it, per CLAUDE.md's Data Safety
   and Approval rule. Nothing after that task depends on the column existing in a live
   database to compile or pass unit tests (Codable round-trip tests use hand-built JSON,
   not a live fetch), so the rest of the sprint is not blocked if approval takes time.

5. **StallDetector session-counting rule:** "4 consecutive sessions" means the 4 most
   recent *completed sessions that included this exercise* (filtered first, then take the
   first 4), not the 4 most recent sessions overall. A user who trains this exercise once
   a week still accumulates qualifying sessions correctly even if they trained other
   exercises in between.

6. **TodayViewModel fetch-cost change:** `fetchBudgetedSets` currently fetches sets only
   when `NextBestSessionEngine.hasGapCandidate` is true (S06 D6 budget). This sprint adds
   a second, smaller budget: when there is no gap candidate, still fetch sets for up to
   `StallDetector.sessionThreshold` (4) of the most recent completed sessions, so
   `StallDetector` has data to work with on ordinary days. This is strictly bounded — not
   the full `baselineSessionWindow + boundedExitSessionCount` budget used for comeback
   detection.

7. **Card mutual exclusion:** `OverloadAdvisorCardView` is computed and stored on
   `TodayData` only inside the `.normal` mode branch of `TodayViewModel.fetch()`, so it
   is structurally impossible for it to coexist with `ComebackCardView` — no extra
   runtime check needed at render time beyond "is `stalledExercise` non-nil."

8. **`Profile.trainingPhase` gets an explicit `= nil` default**, unlike `goal`/
   `daysPerWeek` (added at the struct's inception with no default). This is a retrofit
   onto an existing struct with several `Profile(...)` construction call sites across
   the codebase (`SettingsViewModel`'s preview fake, `SettingsViewModelTests`'
   `makeProfile` helper); a default lets the synthesized memberwise initializer treat it
   as optional-to-pass, so none of those call sites need to change.

9. **Snooze/action clears the card immediately without a full refetch.** Both
   `tryOverloadSuggestion` and `snoozeOverloadSuggestion` set
   `state.value?.stalledExercise = nil` directly after their repository/store call
   succeeds, so the card disappears immediately. The next full `load()`/`refresh()`
   naturally won't re-surface it (weight changed, or the snoozed-until date is in the
   future).

10. **Substitute weight-lookup fetch is sequential, not concurrent.** `presentSubstituteOptions`
    loops over the (typically single-digit) filtered candidate list and awaits
    `fetchLastLoggedSet` one at a time, matching `buildLastSessionReferences`'s existing
    sequential-await style rather than introducing `withTaskGroup` and its actor-isolation
    ceremony for a one-off, small, user-triggered action.

11. **"Not-yet-completed" (not "added after the swap") is what gets reassigned.** A
    section's target sets are pre-created as placeholder rows at session start (before any
    swap), so "new sets get the substitute's identity" means every row with
    `isCompleted == false` at the moment of swap, not literally rows created afterward via
    `addSet(after:)`. This matches the outline's own "already-completed sets keep their
    original exerciseId" framing once you account for how rows are actually created.

---

## 3. RPE UX Simplification — Design (folded in, see plan.md Tasks 1-6 for exact code)

Full rationale lives in `docs/superpowers/specs/2026-07-22-rpe-ux-simplification-design.md`.
Summary: `SetRowView`'s and `SessionDetailView`'s `EditSetSheet`'s raw `Menu` (19 items,
1.0-10.0 step 0.5) both become a 4-item menu built from `HowDidThatFeel.allCases` (Easy /
Just right / Hard) plus a destructive Clear item. `SetRowView`'s closed state shows only
the matching SF Symbol (`face.smiling` / `checkmark.circle` / `flame`) with a new
accessibility label; `EditSetSheet`'s closed state shows the full text label since it has
a `Form` row's worth of horizontal room. A new `HowDidThatFeel.nearest(to:)` bucketing
function displays any legacy/out-of-range stored `Double` at the nearest of the three
canonical points, display-only (never rewrites the stored value). Comeback mode's
`HowDidThatFeelPicker` sheet and the `applyFeedback`/`hasCompletedSets` methods it drove
are deleted since per-set input now captures the same three values directly —
`onFinishExercise` always calls `finishExercise(programExerciseId:)`, comeback or not.

---

## 4. Skip a Day — Design (folded in, see plan.md Tasks 7-9)

Full rationale lives in `docs/superpowers/specs/2026-07-23-skip-a-day-design.md`. Summary:
`TodayView` gains `@State private var selectedDay: ProgramDay?`. A "Change day" `Menu`
control lists `activeProgram.days` sorted by `dayOrder`, excluding the originally
recommended `nextDay`; if that leaves zero alternatives (single-day program), the control
renders nothing. Picking a day sets `selectedDay`; `TodayView.successState` then calls
`comebackCard`/`nextWorkoutCard` with `selectedDay ?? nextDay`, which flows straight
through to each function's own `WorkoutLaunchRoute` construction. `TodayRecommendation` is
never recomputed or mutated — its `adjustments` dictionary already spans every
`programExerciseId` in the whole program (built from `program.days.flatMap(\.exercises)`
inside `NextBestSessionEngine.recommend`), so a swapped-to day's exercises already have
correct comeback ramp data if applicable.

---

## 5. Training Phase Setting — Design (folded in, see plan.md Tasks 10-15)

Full rationale lives in
`docs/superpowers/specs/2026-07-23-training-phase-setting-design.md`. Summary:

### Model

```swift
// Gymbros/Model/Profile.swift
struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var email: String?
    var name: String?
    var experienceLevel: ExperienceLevel?
    var goal: Goal?
    var trainingPhase: TrainingPhase? = nil
    var daysPerWeek: Int?
    var weightUnit: WeightUnit
    var locale: String
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email, name, goal, locale
        case experienceLevel = "experience_level"
        case trainingPhase = "training_phase"
        case daysPerWeek = "days_per_week"
        case weightUnit = "weight_unit"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

`trainingPhase` is optional; `nil` means "not set," and no default is assigned at
signup. `ProfileRepository.updateProfile(_:)` already encodes the whole `Profile` struct
directly (`client.from("profiles").update(profile)`), so no new payload type is needed —
adding the field to `CodingKeys` is sufficient for both read and write.

### Supabase migration (needs explicit approval — see plan.md Task 11)

```sql
alter table public.profiles
    add column if not exists training_phase text null;
```

Additive, non-destructive, matches the existing `program_exercises.target_weight`
migration's style (`supabase/migrations/2026-05-11_program_exercises_target_weight.sql`).

### Settings

`SettingsData` gains `var trainingPhase: TrainingPhase?`. `SettingsViewModel` gains
`updateTrainingPhase(_ phase: TrainingPhase) async`, structured identically to
`updateWeightUnit(_:)`. `SettingsView` gains a new `Menu`-based row in the
`settings.section.preferences` section, following the existing weight-unit row's
`.frame(minHeight: 48)` pattern.

### Localization

| Key | en | th |
|---|---|---|
| `settings.training_phase.title` | Training phase | ช่วงการฝึก |
| `settings.training_phase.maintain` | Maintaining | คงน้ำหนัก |
| `settings.training_phase.cut` | Losing weight | ลดน้ำหนัก |
| `settings.training_phase.bulk` | Building muscle | เพิ่มกล้ามเนื้อ |

---

## 6. Progressive Overload Advisor — Design (folded in, see plan.md Tasks 16-23)

Full rationale lives in
`docs/superpowers/specs/2026-07-23-progressive-overload-advisor-design.md`. Summary:

### StallDetector (new pure service)

```swift
// Gymbros/Data/Services/StallDetector.swift
struct StallDetector {
    static let sessionThreshold = 4
    static let maxRPEForStall = 8.0

    func isStalled(
        exerciseId: UUID,
        recentSessions: [WorkoutSession],   // completed-only, newest-first
        sets: [UUID: [WorkoutSet]]
    ) -> Bool
}
```

A stall is: the same top-set weight logged across the last 4 *qualifying* sessions
(sessions that included this exercise, filtered first, then the newest 4 taken), AND no
session among those 4 recorded an RPE above 8.0 on that top set. Fewer than 4 qualifying
sessions, or a weight that differs across them, is not a stall. `4` reuses
`NextBestSessionEngine.boundedExitSessionCount`'s convention; `8.0` reuses
`ProgressiveOverloadEngine`'s own "hold, don't suggest" ceiling.

### OverloadAdvisorSnoozeStore (new, local-only)

```swift
// Gymbros/Data/Services/OverloadAdvisorSnoozeStore.swift
protocol OverloadAdvisorSnoozing {
    func isSnoozed(programExerciseId: UUID, now: Date) -> Bool
    func snooze(programExerciseId: UUID, now: Date)
}
```

`UserDefaults`-backed, JSON-encoded `[String: Date]` (snoozed-until date keyed by
`programExerciseId.uuidString`), mirroring `RestTimerNotificationScheduler`'s
protocol-wrapped, injectable-`UserDefaults` style for testability. 14-day snooze window.

### TodayViewModel / TodayView wiring

`TodayData` gains `var stalledExercise: StalledExercise?` and `var trainingPhase:
TrainingPhase?`. Computed only when `recommendation.mode.isComeback == false`, scoped to
`recommendation.programDay`'s exercises in `exerciseOrder`, first match wins, filtered
through `OverloadAdvisorSnoozeStore.isSnoozed` and `trainingPhase` (`.cut`/`.maintain`
suppress entirely). `TodayView` renders `OverloadAdvisorCardView` when `stalledExercise`
is non-nil, styled after `ComebackCardView` (same card shape, no custom colors, 48pt tap
targets on both actions).

### Localization

| Key | en | th |
|---|---|---|
| `today.overload_advisor.title` | Same weight for a while | น้ำหนักเท่าเดิมมาสักพัก |
| `today.overload_advisor.body` | You've held %@ on %@ for 4 sessions in a row. | คุณใช้น้ำหนัก %@ กับ %@ มา 4 ครั้งติดกันแล้ว |
| `today.overload_advisor.try_next_time` | Try it next time | ลองครั้งหน้า |
| `today.overload_advisor.not_now` | Not now | ยังไม่ตอนนี้ |
| `accessibility.today.overload_advisor_card` | Overload advisor. %@ | การ์ดแนะนำเพิ่มน้ำหนัก %@ |

---

## 7. Substitute — Design (folded in, see plan.md Tasks 24-30)

Full rationale lives in
`docs/superpowers/specs/2026-07-24-exercise-substitution-design.md`. Summary:

### SubstituteRanker (new pure service)

```swift
// Gymbros/Data/Services/SubstituteRanker.swift
struct SubstituteCandidate: Identifiable, Equatable {
    var id: UUID { exercise.id }
    let exercise: Exercise
    let lastLoggedWeightKg: Double?
}

enum SubstituteRanker {
    static let minimumRankedResultsBeforeBrowseAllFallback = 3

    static func filter(original: Exercise, library: [Exercise]) -> [Exercise]

    static func rank(
        original: Exercise,
        candidates: [Exercise],
        lastLoggedWeightsKg: [UUID: Double]
    ) -> [SubstituteCandidate]
}
```

`filter` runs against `WorkoutSessionData.exerciseLookup.values` — already loaded, no new
query. `rank` sorts by (1) different equipment from original first, (2) has-logged-history
first, (3) name alphabetically.

### WorkoutSessionViewModel additions

```swift
struct SubstitutePrompt: Identifiable {
    let id = UUID()
    let programExerciseId: UUID
    let originalExercise: Exercise
    let candidates: [SubstituteCandidate]
    let showsBrowseAllFallback: Bool
}
```

- `var substitutePrompt: SubstitutePrompt?` drives a `.sheet(item:)` at the
  `WorkoutSessionScreen` level, mirroring how `overloadOutcomePrompt` already drives an
  `.alert`.
- `presentSubstituteOptions(programExerciseId: UUID) async` — resolves the section's
  active exercise (`section.exercise`), filters + fetches weights + ranks, sets
  `substitutePrompt`.
- `selectSubstitute(_ exercise: Exercise) async` — fetches the picked exercise's last
  logged weight, sets `section.exercise = exercise` and `section.defaultWeight`, and for
  every `!isCompleted` row in `section.sets`: reassigns `exerciseId` and reformats
  `weightText` via the existing `formatWeight(_:)` helper. Tracks `.exerciseSubstituted`
  and `.substituteRankSelected`, clears `substitutePrompt`, calls `saveBackup()`.
- `addSet(after:)` changes its hardcoded `exerciseId: ...programExercise.exerciseId` to
  `section.exercise?.id ?? programExercise.exerciseId`.

### Model change

`WorkoutSetRowState.exerciseId`: `let` → `var`. Nothing else in the model changes;
`WorkoutSet.exerciseId` was already per-set server-side and `ActiveSessionBackup` already
encodes both `exercise` and `exerciseId` as they stand today.

### UI

- `WorkoutExercisePageView.exerciseHeader` gains a "Swap exercise" button
  (`arrow.triangle.2.circlepath`), hidden when `section.isFinished`.
- Each row in the set list gets an inline `SubstituteOriginBadge` when its `exerciseId`
  differs from `section.exercise?.id`.
- New `SubstituteCandidateSheet` view: medium-detent, Cancel toolbar action (mirrors
  `FeelPickerSheet`), ranked rows using `EquipmentIconView` + last-weight text, a
  "Browse all exercises" row when `showsBrowseAllFallback` is true that presents the
  existing `ExercisePickerView` unmodified as a nested sheet with the same selection
  closure.
- New `SubstituteOriginBadge` view: same visual family as `EasingBackBadge`/
  `OverloadSuggestionBadge` (capsule, `.caption.weight(.semibold)`, `arrow.uturn.left`).

### Localization

| Key | en | th |
|---|---|---|
| `workout.substitute.button` | Swap exercise | สลับท่า |
| `workout.substitute.sheet.title` | Swap for | สลับเป็น |
| `workout.substitute.sheet.lastWeight` | last: %@ | ครั้งก่อน: %@ |
| `workout.substitute.sheet.browseAll` | Browse all exercises | ดูท่าออกกำลังกายทั้งหมด |
| `workout.substitute.sheet.empty` | No close matches found | ไม่พบท่าที่ใกล้เคียง |
| `workout.substitute.badge` | ↩ %@ | ↩ %@ |
| `accessibility.workout.substitute_button` | Swap exercise | สลับท่าออกกำลังกาย |
| `accessibility.workout.substitute_badge` | Originally %@ | เดิมคือ %@ |

---

## 8. Testing And Acceptance

### Automated tests (see plan.md for exact test code)

- **RPE:** `HowDidThatFeelTests` (bucketing boundaries); `WorkoutSessionViewModelTests`
  loses `applyFeedbackBackFillsRPEForCompletedSets` /
  `applyFeedbackWithNoCompletedSetsSkipsUpdate`, keeps
  `baselineRegainedFiresOncePerSession` unmodified. `ComebackRampServiceTests` and
  `ProgressiveOverloadEngineTests` must pass unmodified — proves zero downstream impact.
- **Skip a Day:** no new/modified unit tests expected (pure `TodayView`-local `@State`);
  build success + manual smoke only, consistent with project convention (Views aren't
  unit-tested, Services are).
- **Training Phase:** `EnumsTests` gains a `TrainingPhase` Codable round-trip test;
  `CodableTests` gains a `Profile` encode/decode test including `training_phase: null`;
  `SettingsViewModelTests` gains `updateTrainingPhase_success` mirroring
  `updateWeightUnit_success`.
- **Progressive Overload Advisor:** `StallDetectorTests` (positive/negative/RPE-gate/
  missing-RPE cases); `OverloadAdvisorSnoozeStoreTests` (snoozed/expired/never-snoozed);
  `TodayViewModelTests` gains cases for card visibility gated on `trainingPhase` and on
  comeback mode.
- **Substitute:** `SubstituteRankerTests` (filter excludes original + wrong
  pattern/muscle; sort order across all three tiers; empty-library edge case);
  `WorkoutSessionViewModelTests` gains cases for `presentSubstituteOptions` (candidates
  ranked correctly, `showsBrowseAllFallback` true/false at the 3-result boundary) and
  `selectSubstitute` (not-yet-completed rows reassigned, completed rows untouched,
  `addSet(after:)` after a swap uses the new exercise, backup round-trips the swap).

### Manual smoke test

```text
1. RPE: log a set with each of Easy/Just right/Hard/Clear in a normal session; confirm
   the closed-state icon updates. Edit a past set in History; confirm the same 4-option
   menu with full text labels. Force a comeback session (existing S06 procedure);
   confirm no end-of-exercise sheet appears and per-set picks still drive the next
   comeback ramp decision.
2. Skip a Day: on a 2+ day program, confirm "Change day" lists every day except the
   recommended one; pick one, confirm Start opens that day; finish it, confirm the next
   recommendation follows the day actually completed. On a 1-day program, confirm the
   control does not appear. Force a comeback scenario, swap day, confirm adjusted
   (ramped-down) weights still apply.
3. Training Phase: open Settings, change training phase, relaunch (or pull-to-refresh),
   confirm it persisted.
4. Progressive Overload Advisor: log the same weight for an exercise across 4 sessions
   at RPE <=8.0; confirm the card appears on Today (normal mode only). Set training
   phase to "Losing weight"; confirm it disappears for that exercise. Set back to
   "Building muscle" (or clear it); confirm it reappears. Tap "Not now"; confirm it
   stays hidden across a relaunch. On a fresh (unsnoozed) stall, tap "Try it next time";
   confirm the program exercise's target weight increased by 2.5kg and the card is gone.
5. Substitute: mid-workout, tap "Swap exercise" on an exercise with 3+ ranked candidates
   in the library; confirm the ranked sheet excludes the current exercise, sorts
   different-equipment-first, and shows "last: Xkg" for exercises already logged this
   week. Pick one; confirm the header updates, not-yet-completed sets show the new
   exercise's suggested weight, and already-completed sets are unchanged. Finish the
   workout; open it in History and confirm completed sets under the original exercise
   still show correctly. Swap again to a third exercise; confirm re-swapping works.
   Force an exercise with <3 candidates (a rare movement/muscle combo); confirm "Browse
   all exercises" appears and opens the full picker.
6. Run in both Thai and English device locales; verify all new copy from all five
   features renders correctly.
```

### Build and test

```bash
xcodebuild test \
  -project Gymbros.xcodeproj \
  -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### GYMTRACK + STANDUP updates after sprint

- Update `.claude/GYMTRACK.md` §9 Sprint Tracking row 6.1 status to fully complete once
  all 5 features are manually smoke-tested.
- Update `STANDUP.md` with HEAD SHA, sprint outcome per feature, and next-up.
