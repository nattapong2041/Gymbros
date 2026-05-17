# Sprint 4 - Today + History + Navigation + Anti-Guilt UX

> Detailed implementation spec for coding agents.
> Reference: `.claude/GYMTRACK.md` Section 9 - Phase 1, Sprint 4

---

## Overview

**Goal:** Give a signed-in user a home today screen showing what to do next, tab navigation to reach programs and session history, and an anti-guilt experience that never shames missed days or broken streaks.

**Primary acceptance test:** Open the app after sign-in — a Today tab shows a greeting, a next-workout card, and a Start CTA that opens the existing workout logger. Navigate to History and see completed sessions newest-first. Tap any session to see a read-only set detail view. After 7+ days of no workouts a welcome-back banner appears. Streak is shown only when ≥2 consecutive weeks have been logged.

**Effort estimate:** Medium.

**Dependencies:** Sprint 3 is complete. `WorkoutRepository.fetchHistory(limit:)` exists. `ProgramRepository.fetchActive()` exists. `RootView` authenticates but currently shows `ProgramListView` directly — Sprint 4 replaces this with a `TabView`.

---

## 1. Requirements

### Must Have

```text
✓ TabView with 3 tabs: Today (home), Programs, History
  — Today is the default (index 0)
  — Each tab root owns its own NavigationStack
  — Settings tab added in Sprint 5
✓ TodayView
  — Greeting by time-of-day (morning / afternoon / evening)
  — If no active program: "Ready when you are" empty state
  — If active program: next-workout card (day name, exercise preview)
  — Start CTA on the card opens WorkoutSessionScreen
  — Welcome-back banner after 7+ days since last session
  — Streak badge visible only when intact (≥2 consecutive weeks)
  — Last-workout date shown in secondary/soft colour, never shaming copy
✓ TodayViewModel (@Observable)
  — Loads fetchActive() + fetchHistory()
  — Derives next program day and streak via StreakService
  — ViewState<TodayData> + transientError: AppError?
✓ HistoryView
  — List of completed sessions, newest first
  — Each row: day name, date (workoutDisplayString), duration
  — Empty state: encouraging, non-shaming copy
  — Tap → SessionDetailView
✓ SessionDetailView (read-only)
  — Session date, duration
  — Sets grouped per exercise
  — No edit affordance this sprint
✓ HistoryViewModel + SessionDetailViewModel (@Observable)
  — HistoryViewModel: fetchHistory(limit: 50)
  — SessionDetailViewModel: fetchSets(sessionId:)
  — ViewState<…> + transientError: AppError?
✓ StreakService (pure Swift, Data/Services/, unit-tested)
  — Week-based: count consecutive prior calendar weeks ≥1 session each
  — Current week never breaks the streak
  — Returns 0 when streak < 2 (hidden threshold)
  — Never exposes a "broken" state
✓ Anti-guilt UX rules (enforced throughout)
  — Streak shown only when ≥2 intact consecutive weeks
  — Last-workout date in .secondary colour, no judgment copy
  — Welcome-back banner (not a warning) after 7+ days idle
  — No "streak broken", "you missed", or "you failed" copy anywhere
✓ All visible strings localized in Thai and English
✓ All user-visible errors flow through AppError/ViewState
✓ App builds and tests pass on iPhone 17e simulator
```

### Out of Scope

```text
✗ Settings (Sprint 5)
✗ Smart Comeback / Next Best Session Engine (Sprint 6)
✗ Editing past sets of SessionDetailView (deferred)
✗ HealthKit
✗ Onboarding
✗ Push notifications
✗ Progress graphs / charts
✗ Program day creation or editing from Today
```

---

## 2. Existing Foundation To Reuse

```text
Gymbros/Data/Repository/WorkoutRepository.swift     — fetchHistory(limit:)
Gymbros/Data/Repository/ProgramRepository.swift     — fetchActive()
Gymbros/Data/Repository/ProfileRepository.swift     — fetchCurrentProfile()
Gymbros/Model/WorkoutSession.swift                  — startedAt/endedAt/isComplete/duration
Gymbros/Model/WorkoutSet.swift
Gymbros/Model/Program.swift + ProgramDay.swift      — dayOrder
Gymbros/Core/ErrorHandling/AppError.swift
Gymbros/Core/ErrorHandling/ViewState.swift
Gymbros/Core/ErrorHandling/ErrorMapper.swift
Gymbros/Core/Extensions/Date+Extensions.swift       — relativeString, workoutDisplayString
Gymbros/Core/AppTheme.swift                         — Color.gymSurface, Color.gymBackground, Font.gymNumber
Gymbros/Presentation/Programs/ErrorAlertModifier.swift — .transientErrorAlert modifier
Gymbros/App/RootView.swift                          — to be refactored for TabView
Gymbros/Resources/Localizable.xcstrings
Gymbros/Presentation/Workout/WorkoutSessionScreen.swift — existing entry point for logger
```

Canonical ViewModel pattern to follow: `ProgramListViewModel` — `state: ViewState<…>` + `transientError: AppError?`.

Rules:

- Use concrete `@Observable` ViewModels — no protocols (except `ProfileRepositoryProviding` which is Sprint 5).
- The spec and plan are the coordination contract between parallel agents.
- Keep models `Codable` with explicit `CodingKeys`.
- Repository methods may be `async throws`, but anything thrown outside the data layer must be `AppError`.
- Do not expose raw Supabase errors, SQL details, status codes, or `localizedDescription` in SwiftUI.
- The whole app uses SwiftUI system and semantic colors only.

---

## 2.1 Spec Lock Decisions

Task 0 locks these decisions before parallel work starts:

**Streak logic:**
- Streak = count of consecutive prior calendar weeks (Mon–Sun) each containing ≥1 completed session (`isComplete == true`), counting backward from the most-recently-completed-week before the current week.
- The current calendar week (containing today) is never counted and never breaks the streak.
- Streak is hidden (returns 0 / not rendered) when the result is < 2 consecutive weeks.
- `StreakService` never surfaces the word "broken" or any negative framing — callers receive an `Int` and decide whether to render it.
- `StreakService` input: `[WorkoutSession]` (completed, any order); output: `Int`.

**Next-day logic:**
- Next day = the `ProgramDay` whose `dayOrder` immediately follows the `programDayId` of the most-recently-completed session, ordered by ascending `dayOrder`, wrapping around to the first day after the last.
- If no history exists → first day (lowest `dayOrder`).
- If no active program → nil (empty state).
- Logic lives in `TodayViewModel`; no separate service needed.

**Tab navigation:**
- `TabView` introduced in `RootView` authenticated branch (Task 4).
- 3 tabs: Today (house icon), Programs (list icon), History (clock icon).
- Today is tab index 0 (default selected).
- Each tab wraps its root view in its own `NavigationStack`.
- Sprint 5 inserts a 4th Settings tab; do not add a placeholder in Sprint 4.

**SessionDetailView:**
- Read-only this sprint. No edit affordance, no swipe-to-delete on sets.
- Editing past sets is deferred and noted in the roadmap.

**`fetchSets(sessionId:)`:**
- New method added to `WorkoutRepository` in Task 1.
- Returns `[WorkoutSet]` for a given session, ordered by exercise then set number.
- Flows through `ErrorMapper.map(error, context:)`.

**Anti-guilt copy rules (enforced across all copy):**
- No "streak broken", "missed", "failed", "behind", "you haven't trained", "don't break the streak".
- Welcome-back banner copy: positive framing only ("Welcome back! Ready to pick up where you left off?").
- Empty state: "Ready when you are." (no judgment).
- Last-workout date: show as relative/natural date in `.secondary` colour only.

---

## 2.2 Locked at Task 0

These decisions were open or ambiguous in the original spec and are now locked. All parallel tasks (1–7) must follow these as-written.

**Lock 1 — ViewModel init signatures (canonical codebase pattern):**
- `TodayViewModel(programRepository: ProgramRepositoryProviding? = nil, workoutRepository: WorkoutRepositoryProviding? = nil)`
- `HistoryViewModel(workoutRepository: WorkoutRepositoryProviding? = nil, programRepository: ProgramRepositoryProviding? = nil)`
- `SessionDetailViewModel(session: WorkoutSession, workoutRepository: WorkoutRepositoryProviding? = nil, exerciseRepository: ExerciseRepositoryProviding? = nil)`
- Default `nil` → concrete fallback (e.g. `workoutRepository ?? WorkoutRepository()`). Tests inject `Fake*Repository`.

**Lock 2 — `fetchSets` on the protocol, not only the class:**
- Task 1 adds `func fetchSets(sessionId: UUID) async throws -> [WorkoutSet]` to `WorkoutRepositoryProviding` AND `WorkoutRepository`.
- `FakeWorkoutRepository` (used in tests) must also implement it.

**Lock 3 — `SessionDetailData.exerciseLookup` is non-optional:**
- Type is `[UUID: Exercise]` (not `[UUID: Exercise]?`).
- `SessionDetailViewModel` injects `ExerciseRepositoryProviding`, calls `fetchAll()`, builds the lookup via the existing `ProgramViewModelSupport.exerciseLookup(from:)` helper.
- If the exercise fetch fails: use an empty dict; set rows still render. An unresolved `exerciseId` falls back to the key `session.exercise.unknown` ("Exercise" / "ท่าออกกำลังกาย") as the section header.

**Lock 4 — History row day-name resolution:**
- `HistoryData` gains `dayNames: [UUID: String]` (programDayId → day name string).
- `HistoryViewModel` injects `ProgramRepositoryProviding`, calls `fetchHistory(limit: 50)` and `fetchAll()` concurrently, flattens every program's `.days` into the lookup.
- Row layout: program day name as headline; `workoutDisplayString` date + duration as subheadline.
- Session with `nil` `programDayId` or an id not in the lookup → show localized `history.session.custom` ("Custom workout" / "เวิร์กเอาท์ทั่วไป").

**Lock 5 — Next-day fallback when `programDayId` is nil or stale:**
- In `TodayViewModel`, after finding the most-recently-completed session: if its `programDayId` is `nil` OR not among the active program's days, fall back to the first day (lowest `dayOrder`). Otherwise pick the day immediately after it (ascending `dayOrder`), wrapping to the first day after the last.

**Lock 6 — StreakService calendar is always `iso8601`:**
- `StreakService` creates `Calendar(identifier: .iso8601)` explicitly. Never `Calendar.current`.
- This makes all week-grouping and current-week computation deterministic regardless of device locale.

**Lock 7 — `fetchActive()` returns a fully-hydrated Program:**
- `ProgramRepository.fetchActive()` calls `fetchFull(id:)` internally; `Program.days` is populated and each `ProgramDay.exercises` is populated.
- Tasks 2 and 5 rely on `nextDay.exercises` directly — no extra exercise fetch needed for the Today card exercise preview.

**Lock 8 — Workout session presentation: push, not modal:**
- Verified: the only existing `WorkoutSessionScreen` call site (`DayBuilderView.swift:98`) uses `.navigationDestination(isPresented:)` — a push within the surrounding `NavigationStack`.
- `TodayView` must match this pattern: use `.navigationDestination(item:)` bound to an optional `UUID?` state (the next-day id). Do NOT use `.sheet` or `.fullScreenCover`.
- No "streak broken", "missed", "failed", "behind", "you haven't trained", "don't break the streak".
- Welcome-back banner copy: positive framing only ("Welcome back! Ready to pick up where you left off?").
- Empty state: "Ready when you are." (no judgment).
- Last-workout date: show as relative/natural date in `.secondary` colour only.

**Mock data:**
- Each new view file has a corresponding `*MockData.swift` in the same folder used only in `#if DEBUG` / `PreviewProvider` scope.

---

## 3. Product Flow

```text
App launch (authenticated)
→ RootView → TabView (Today selected by default)
     Tab 0 — Today
          TodayView
          [empty: no active program] "Ready when you are"
          [has program, no history] first-day card → Start CTA
          [has program, has history] next-day card → Start CTA
          [7+ days idle] welcome-back banner above card
          [streak ≥2 weeks] streak badge on card
          Start CTA → WorkoutSessionScreen(programDayId:)
     Tab 1 — Programs
          ProgramListView (existing, unchanged)
     Tab 2 — History
          HistoryView → SessionDetailView (read-only)
```

---

## 4. Data Shapes

### TodayData

```text
activeProgram: Program?
nextDay: ProgramDay?
recentSessions: [WorkoutSession]    // limit 50
streakWeeks: Int                     // 0 when < 2 (hidden)
lastSessionDate: Date?
isWelcomeBack: Bool                  // true when 7+ days since last session
```

### HistoryData

```text
sessions: [WorkoutSession]           // completed, newest first
dayNames: [UUID: String]             // programDayId → day name; built by HistoryViewModel from fetchAll()
```

### SessionDetailData

```text
session: WorkoutSession
sets: [WorkoutSet]
exerciseLookup: [UUID: Exercise]     // non-optional; empty dict when exercise fetch fails
```

---

## 5. ViewModels

### TodayViewModel

```swift
@MainActor
@Observable
final class TodayViewModel {
    var state: ViewState<TodayData>
    var transientError: AppError?

    init(
        programRepository: ProgramRepositoryProviding? = nil,
        workoutRepository: WorkoutRepositoryProviding? = nil
    )
    func load() async
    func refresh() async
}
```

Internal logic:
- Calls `ProgramRepository.fetchActive()` and `WorkoutRepository.fetchHistory(limit: 50)` concurrently.
- Passes completed sessions to `StreakService.streak(from:)`.
- Derives `nextDay` from history + active program days sorted by `dayOrder`. If the most-recently-completed session's `programDayId` is `nil` or not in the active program's days, falls back to the first day (lowest `dayOrder`).
- Sets `isWelcomeBack = true` when `lastSessionDate` is ≥7 days ago or history is empty and a program exists.
- `fetchActive()` returns a fully-hydrated `Program`; rely on `nextDay.exercises` directly for exercise preview.

### HistoryViewModel

```swift
@MainActor
@Observable
final class HistoryViewModel {
    var state: ViewState<HistoryData>
    var transientError: AppError?

    init(
        workoutRepository: WorkoutRepositoryProviding? = nil,
        programRepository: ProgramRepositoryProviding? = nil
    )
    func load() async
}
```

Internal logic:
- Calls `WorkoutRepository.fetchHistory(limit: 50)` and `ProgramRepository.fetchAll()` concurrently.
- Flattens every program's `.days` into `dayNames: [UUID: String]` (programDayId → day name).

### SessionDetailViewModel

```swift
@MainActor
@Observable
final class SessionDetailViewModel {
    var state: ViewState<SessionDetailData>
    var transientError: AppError?

    init(
        session: WorkoutSession,
        workoutRepository: WorkoutRepositoryProviding? = nil,
        exerciseRepository: ExerciseRepositoryProviding? = nil
    )
    func load() async
}
```

Internal logic:
- Calls `WorkoutRepository.fetchSets(sessionId:)` and `ExerciseRepository.fetchAll()` concurrently.
- Builds `exerciseLookup` using `ProgramViewModelSupport.exerciseLookup(from:)`. Falls back to empty dict if exercise fetch fails.

---

## 6. StreakService

Location: `Gymbros/Data/Services/StreakService.swift`

Pure Swift — no I/O, no dependencies, 100% unit-tested.

```swift
struct StreakService {
    /// Returns the number of consecutive prior calendar weeks (Mon–Sun) each
    /// containing ≥1 completed session, counting backward from the week
    /// immediately before the current week.
    /// The current week never breaks the streak.
    /// Returns 0 when the streak is < 2 (callers treat 0 as "hidden").
    func streak(from sessions: [WorkoutSession], today: Date = .now) -> Int
}
```

Algorithm:
1. Filter `sessions` to only `isComplete == true`.
2. Create `var cal = Calendar(identifier: .iso8601)` — **never** use `Calendar.current` (device locale affects first weekday, making tests non-deterministic).
3. Group sessions by `(yearForWeekOfYear, weekOfYear)` using that calendar.
4. Determine `currentWeek` from `today` using the same calendar.
5. Starting from the week immediately before `currentWeek`, count consecutive weeks that have ≥1 session. Stop at the first gap.
6. If count < 2, return 0. Otherwise return count.

---

## 7. UI Requirements

### TodayView

States:
- `.loading`: progress indicator
- `.error(AppError)`: localized retry UI
- `.success(TodayData)`:
  - No program: full-screen "Ready when you are" empty state with a CTA to Programs tab.
  - Has program: greeting text + optional welcome-back banner + next-workout card.
- No distinct `.empty` state — empty program state is handled in `.success`.

Next-workout card layout:
- Day name (title), exercise preview (2–3 names or count).
- Streak badge (only when `streakWeeks >= 2`): e.g. "3 weeks" — no fire emoji, no pressure copy.
- Last-workout date in `.secondary` colour (e.g. "3 days ago").
- Start button: primary CTA. Tapping pushes `WorkoutSessionScreen(programDayId:)` via `.navigationDestination(item:)` bound to an optional `UUID?` state — do NOT use `.sheet` or `.fullScreenCover`.
- Welcome-back banner (visible when `isWelcomeBack`): positive tone, not a warning.

Color policy: system and semantic only. Use `.primary`, `.secondary`, `.systemBackground`, `.secondarySystemBackground`. A `.blue` tint is acceptable for the Start CTA.

Minimum tap target: 48pt for the Start button.

### HistoryView

States:
- `.loading`: progress indicator
- `.empty`: encouraging empty state ("No workouts yet. Your first one is waiting.")
- `.error(AppError)`: localized retry
- `.success(HistoryData)`: session list

Session row layout:
- Headline: program day name (from `dayNames[session.programDayId]`). Sessions with a `nil` or unresolved `programDayId` show the localized `history.session.custom` label ("Custom workout").
- Subheadline: `workoutDisplayString` date + duration (e.g. "42 min").
- Tap navigates to `SessionDetailView`.

### SessionDetailView

States:
- `.loading`: progress indicator
- `.error(AppError)`: localized retry
- `.success(SessionDetailData)`: read-only set list

Layout:
- Navigation title: session date
- Subheader: total duration
- Sections per exercise: exercise name (from `exerciseLookup`), then set rows (set number, weight, reps, optional RPE). If a set's `exerciseId` is not in the lookup, use localized `session.exercise.unknown` ("Exercise") as the section header.
- No edit affordance, no swipe-delete, no add-set

---

## 8. Repository Contract

### Existing (reuse)

```swift
// ProgramRepository
func fetchActive() async throws -> Program?

// WorkoutRepository
func fetchHistory(limit: Int = 50) async throws -> [WorkoutSession]
```

### New (Task 1 adds)

```swift
// WorkoutRepositoryProviding protocol — add this method:
func fetchSets(sessionId: UUID) async throws -> [WorkoutSet]

// WorkoutRepository concrete class — implement it:
func fetchSets(sessionId: UUID) async throws -> [WorkoutSet]
```

Both the **protocol** (`WorkoutRepositoryProviding`) and the **concrete class** (`WorkoutRepository`) must have this method. `FakeWorkoutRepository` in tests must implement it too.

Implementation notes:
- Query `workout_sets` filtered by `session_id == sessionId`, ordered by `exercise_id` then `set_number`.
- Map through `ErrorMapper.map(error, context:)`.
- Do not introduce `RepositoryError`; use `AppError`.
- Return `[]` (not nil or `.notFound`) when no sets exist for the session (valid empty state).

---

## 9. Localization

Add complete Thai and English copy for these key families:

```text
today.title                   // "Today"
today.greeting.morning        // "Good morning" / "อรุณสวัสดิ์"
today.greeting.afternoon      // "Good afternoon" / "สวัสดีตอนบ่าย"
today.greeting.evening        // "Good evening" / "สวัสดีตอนเย็น"
today.next_workout.title      // "Next workout" / "การออกกำลังกายถัดไป"
today.start_cta               // "Start" / "เริ่ม"
today.streak.weeks            // "%lld weeks" / "%lld สัปดาห์"
today.last_workout            // "Last workout %@" / "ออกกำลังกายล่าสุด %@"
today.welcome_back            // "Welcome back! Ready to pick up where you left off?"
today.empty.no_program        // "Ready when you are."
today.empty.programs_cta      // "Create a program" / "สร้างโปรแกรม"

history.title                 // "History" / "ประวัติ"
history.empty                 // "No workouts yet. Your first one is waiting."
history.session.duration      // "%lld min" / "%lld นาที"
history.session.custom        // "Custom workout" / "เวิร์กเอาท์ทั่วไป"

session.title                 // session date string
session.duration              // "Duration: %lld min"
session.set.weight_reps       // "%@ kg × %lld"  (or "%@ lb × %lld")
session.set.rpe               // "RPE %@"
session.exercise.unknown      // "Exercise" / "ท่าออกกำลังกาย"  (fallback when exerciseId not in lookup)

accessibility.today.start           // "Start workout for %@"
accessibility.today.streak          // "Streak: %lld weeks"
accessibility.history.session_row   // "%@, %lld minutes"
```

Include all titles, messages, buttons, errors, empty states, and accessibility labels.

---

## 10. Testing And Acceptance

### Automated tests

StreakService:
- Zero sessions → returns 0
- Sessions only in current week → returns 0 (current week not counted)
- One complete prior week → returns 0 (below threshold of 2)
- Two consecutive prior weeks → returns 2
- Five consecutive prior weeks → returns 5
- Gap two weeks ago (week 1 and week 3 but not week 2) → returns 1 → hidden (0)
- Incomplete sessions excluded
- Sessions spanning a year boundary (Dec/Jan) handled correctly

TodayViewModel (mock repositories):
- No active program → state is `.success` with `nil` nextDay
- Active program, no history → nextDay is first day (lowest `dayOrder`)
- Active program, one session → nextDay wraps correctly
- Last session > 7 days ago → `isWelcomeBack == true`
- Last session within 7 days → `isWelcomeBack == false`
- Repository error → state is `.error`

HistoryViewModel (mock repositories):
- No sessions → state is `.empty`
- Sessions returned → state is `.success`
- Session with a known `programDayId` → `dayNames` lookup resolves correct day name
- Session with `nil` or unknown `programDayId` → view renders `history.session.custom` label

SessionDetailViewModel (mock repository):
- Session with no sets → state is `.success` with empty set list
- Session with sets → sets grouped per exercise

### Manual smoke test

```text
1. Sign in. Today tab appears by default.
2. No active program: "Ready when you are" empty state visible.
3. Create a program with 3 days. Return to Today. Next-workout card appears.
4. Start a workout and finish it. Return to Today. Card shows next day in sequence.
5. Navigate to History. The finished session appears with correct date and duration.
6. Tap the session. Set detail view shows sets grouped per exercise. No edit affordance.
7. Manually set last session date to 8 days ago (or test via mock).
   Welcome-back banner appears. No negative copy.
8. Log 2 workouts in the prior week and 2 in the week before that.
   Streak badge shows "2 weeks". No "streak broken" copy anywhere.
9. Tap Programs tab. ProgramListView loads correctly.
10. Background-launch the app. Returns to Today tab.
```

Build/test:

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'
```
