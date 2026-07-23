# Training Phase Setting — Design

**Date:** 2026-07-23
**Status:** Approved, pending implementation plan
**Author:** Brainstormed with Claude Code

## Context

Split off from brainstorming feature #3 of the post-launch backlog (progressive
overload advisor — see `.claude/GYMTRACK.md` → "Post-Launch Feature Backlog"). While
designing the advisor, the user raised a real concern: someone in a caloric deficit,
deliberately trying to hold their weights steady while losing fat, shouldn't get nagged
to add weight. The app has no nutrition tracking (explicitly out of scope for V1 per
`.claude/GYMTRACK.md` §"Non-Goals" — "Nutrition: Partner/integrate later, do not build
V1"), so there's no way to *infer* this. The fix is to let the user *tell* the app
directly, which needs its own small, foundational setting — bigger than a one-line
tweak to the advisor, and useful independent of it.

This spec covers only the setting itself: persisting a training phase on the user's
profile and letting them change it in Settings. The follow-up spec (progressive
overload advisor) will consume this value; it does not yet exist as of this writing.

## Discovery

`Gymbros/Model/Enums/TrainingPhase.swift` already exists:

```swift
enum TrainingPhase: String, Codable, CaseIterable {
    case bulk, cut, maintain
}
```

It is completely unused elsewhere in the codebase (confirmed via repo-wide search) —
leftover scaffolding from early data modeling that was never wired to `Profile`, to
Settings, or to any service. This spec finishes wiring it up. The case names stay
exactly as they are (they're just code identifiers); only the user-facing display
copy changes (see Localization below).

This is a distinct concept from the existing `goal: Goal?` field on `Profile`
(`strength` / `muscle` / `fatLoss` / `general`) — `Goal` is the user's long-term
aspiration (set once, rarely changes), `TrainingPhase` is their current short-term
nutritional cycle (changes every few months as they move between building and cutting).
Both are complementary; this spec does not merge or replace `Goal`.

## Goal

Let the user set and change "Maintaining" / "Losing weight" / "Building muscle" as a
profile-level setting, persisted to Supabase, editable in Settings — with no behavior
change anywhere else in the app yet.

## Non-goals

- No behavior change triggered by this setting — no feature reads it yet. That's the
  follow-up progressive-overload-advisor spec's job.
- No onboarding wiring. Sprint 7 (`.claude/GYMTRACK.md` → Sprint 7 —
  Onboarding + Templates + i18n) isn't built yet; Settings is the only currently-shipped
  place a user can change profile preferences (see the existing weight-unit toggle),
  so that's where this goes for now. Onboarding can ask for it later once Sprint 7
  exists.
- No merging/reconciling with the existing `Goal` field.
- No actual calorie/nutrition tracking — this is a single self-reported enum, not a
  diet tracker.

## Design

### Model

Add to `Gymbros/Model/Profile.swift`:

```swift
struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var email: String?
    var name: String?
    var experienceLevel: ExperienceLevel?
    var goal: Goal?
    var trainingPhase: TrainingPhase?
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

`trainingPhase` is optional, matching `goal`'s existing optionality — `nil` means "not
set." No default value is assigned at signup; a user who's never opened this Settings
row simply has `nil`. It is the *consumer's* job (the future advisor) to decide how to
treat `nil` — not this spec's.

### Supabase

Needs a migration adding a nullable `training_phase text` column to the `profiles`
table. This is additive and non-destructive, but per the project's Data Safety and
Approval rule (`CLAUDE.md` → "Data Safety and Approval"), applying any migration still
requires explicit user confirmation at implementation time — this spec does not
pre-authorize it.

### Settings UI

Mirrors the existing weight-unit toggle pattern exactly
(`Gymbros/Presentation/Settings/SettingsViewModel.swift`):

- `SettingsData` gains `var trainingPhase: TrainingPhase?`.
- `SettingsViewModel` gains `func updateTrainingPhase(_ phase: TrainingPhase) async`,
  structured identically to the existing `updateWeightUnit(_:)`: fetch the current
  profile, mutate the field, persist via `ProfileRepositoryProviding`, update local
  `SettingsData` on success.
- `SettingsView` gets a new row (a `Menu` or `Picker`, consistent with existing Settings
  row styling) listing the three phases by their localized display name.

### Localization

New keys — the enum's raw case names (`bulk`/`cut`/`maintain`) are never shown to the
user directly:

| Key | en | th |
|---|---|---|
| `settings.training_phase.title` | Training phase | ช่วงการฝึก |
| `settings.training_phase.maintain` | Maintaining | คงน้ำหนัก |
| `settings.training_phase.cut` | Losing weight | ลดน้ำหนัก |
| `settings.training_phase.bulk` | Building muscle | เพิ่มกล้ามเนื้อ |

## Testing

- `EnumsTests.swift` (or wherever `Goal`'s Codable round-trip is tested — same file, same
  pattern) gets a matching round-trip test for `TrainingPhase`.
- A `CodableTests`-style test confirming `Profile` encodes/decodes `training_phase`
  correctly, including when `nil`.
- `SettingsViewModelTests` gets a new test for `updateTrainingPhase`, mirroring the
  existing `updateWeightUnit` test (success path + persisted value reflected in
  `SettingsData`).
- Build must succeed; manual smoke: open Settings, change the training phase, relaunch
  the app (or pull-to-refresh Settings), confirm the change persisted.

## Open follow-ups

- The progressive overload advisor (feature #3 proper) is the first and only planned
  consumer of this value — not designed yet, comes next.
- Onboarding wiring (Sprint 7) is deferred, not rejected — worth revisiting once that
  sprint starts.
