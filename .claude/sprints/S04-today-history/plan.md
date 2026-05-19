# Sprint 4 - Today + History + Navigation + Anti-Guilt UX Implementation Plan

> **For agentic workers:** Read `CLAUDE.md`, `.claude/GYMTRACK.md`, this sprint's `spec.md`, and this `CURRENT STATUS` block before starting. Mark each checkbox `[x]` immediately after completing it. Preserve unrelated user changes.

**Goal:** Home screen (Today), History, tab navigation, and anti-guilt UX.

---

## CURRENT STATUS

**Status:** Task 7 complete in `worktree-s04-task7-localization`. Other parallel Sprint 4 tasks may continue; Task 8 waits on all handoffs.

**Done:** Task 0 — Spec Lock: 8 ambiguities resolved (see §2.2 in spec.md for all locked decisions). Task 7 — Sprint 4 localization keys added to `Localizable.xcstrings` with Thai and English values.

**Last commit SHA:** b59cd8e (Task 7 worktree base; Task 7 changes not committed)

**Known deviations / constraints:**
- Use simulator `iPhone 17e` in all `xcodebuild` commands.
- Module name is `Gymbros`.
- Tests use Swift Testing (`import Testing`, `#expect`, `@Suite`, `@Test`), not XCTest.
- Xcode 16 auto-discovers files under `Gymbros/`; do not edit `project.pbxproj` to add files.
- Whole app uses SwiftUI system and semantic colors only. No custom brand colors.
- Settings tab is NOT part of Sprint 4 — it is Sprint 5. Do not add a placeholder Settings tab.
- SessionDetailView is read-only this sprint. No editing past sets.
- Do not add HealthKit, onboarding, notifications, progress graphs, or Smart Comeback in Sprint 4.
- `WorkoutSessionScreen` presentation: push via `.navigationDestination(item:)` within the Today tab's `NavigationStack` — NOT `.sheet` or `.fullScreenCover`.
- `StreakService` must use `Calendar(identifier: .iso8601)`, never `Calendar.current`.
- `SessionDetailData.exerciseLookup` is `[UUID: Exercise]` (non-optional). Unresolved ids → `session.exercise.unknown` fallback header.
- `HistoryData` carries `dayNames: [UUID: String]`. Unresolved/nil `programDayId` → `history.session.custom` label.
- Task 7 worktree is based on `b59cd8e`, so `Presentation/Today/` and `Presentation/History/` view files were not available for hardcoded-string replacement here. Task 8 should run the final SwiftUI string grep after merging UI tasks.
- Anti-guilt grep has one pre-existing stale non-Sprint-4 key, `workout.sync.failed`; no new Sprint 4 copy uses shaming language.

**Next step:** Continue/merge remaining parallel tasks, then run Task 8 (Wire + Verify).

---

## Parallel Execution Map

Task 0 is sequential and locks the shared shape.

After Task 0 is complete, these can run in parallel:

- **Task 1 — fetchSets + StreakService + tests:** owns new repository method, StreakService, unit tests.
- **Task 2 — TodayViewModel + tests:** owns TodayViewModel and its tests.
- **Task 3 — HistoryViewModel + SessionDetailViewModel + tests:** owns both history-side ViewModels and tests.
- **Task 5 — TodayView + mock + previews:** owns Today UI (parallel with Tasks 2/3).
- **Task 6 — HistoryView + SessionDetailView + mock + previews:** owns History UI (parallel with Tasks 2/3).
- **Task 7 — Localization:** owns `Localizable.xcstrings` for all new keys.

Task 4 (Tab shell) and Task 8 (Wire + Verify) are sequential integration tasks.

Recommended execution order:
```
Task 0 (sequential)
  ├── Task 1 + Task 2 + Task 3 + Task 5 + Task 6 + Task 7 (parallel)
Task 4 (after Task 0, can overlap with Tasks 1–3 since it only touches RootView)
Task 8 (sequential, after all above)
```

---

## Task 0: Spec Lock

**Owner:** Sequential first worker.

**Parallel-safe ownership:** Documentation only. Do not implement repositories, ViewModels, or SwiftUI in this task.

**Files likely touched:**
- `.claude/sprints/S04-today-history/spec.md`
- `.claude/sprints/S04-today-history/plan.md`

**Forbidden files:**
- `Gymbros/Data/Repository/WorkoutRepository.swift`
- `Gymbros/Presentation/Today/*`
- `Gymbros/Presentation/History/*`
- `Gymbros/Resources/Localizable.xcstrings`
- `Gymbros/App/RootView.swift`

- [x] Confirm spec names concrete `TodayViewModel`, `HistoryViewModel`, `SessionDetailViewModel` public state and actions clearly enough for parallel work.
- [x] Confirm spec defines `TodayData`, `HistoryData`, `SessionDetailData`.
- [x] Confirm `StreakService` algorithm and hidden-threshold rule (< 2 = hidden) are documented.
- [x] Confirm `fetchSets(sessionId:)` contract is specified.
- [x] Confirm localization key families are listed for Task 7.
- [x] Confirm Task 1–7 ownership boundaries are clear.
- [x] Update `CURRENT STATUS` with any lock changes and the next parallel tasks.

**Verification:** Documentation review only.

**Handoff notes:**
8 decisions locked in spec.md §2.2:
1. VM init signatures — `nil`-defaulted protocol params, concrete fallback in body.
2. `fetchSets` added to `WorkoutRepositoryProviding` protocol AND concrete class (and fake in tests).
3. `SessionDetailData.exerciseLookup` is `[UUID: Exercise]` (non-optional); `ExerciseRepositoryProviding` injected; fallback key `session.exercise.unknown`.
4. `HistoryData` gains `dayNames: [UUID: String]`; `HistoryViewModel` injects `ProgramRepositoryProviding`; fallback key `history.session.custom`.
5. Next-day fallback: nil/stale `programDayId` → first day (lowest `dayOrder`).
6. `StreakService` uses `Calendar(identifier: .iso8601)` — never `Calendar.current`.
7. `fetchActive()` returns a fully-hydrated `Program`; Tasks 2/5 rely on `nextDay.exercises` directly.
8. `TodayView` pushes `WorkoutSessionScreen` via `.navigationDestination(item:)` within the tab's `NavigationStack` (matching `DayBuilderView` pattern) — not a modal.

---

## Task 1: fetchSets + StreakService + Tests

**Owner:** Data worker. Parallel-safe after Task 0.

**Parallel-safe ownership:** Own `WorkoutRepository.fetchSets`, `StreakService`, and their tests. Do not touch SwiftUI view files or Localizable.xcstrings.

**Files likely touched:**
- `Gymbros/Data/Repository/WorkoutRepository.swift`
- `Gymbros/Data/Services/StreakService.swift` (new)
- `GymbrosTests/StreakServiceTests.swift` (new)

**Forbidden files:**
- `Gymbros/Presentation/Today/*`
- `Gymbros/Presentation/History/*`
- `Gymbros/App/RootView.swift`
- `Gymbros/Resources/Localizable.xcstrings`

- [ ] Add `func fetchSets(sessionId: UUID) async throws -> [WorkoutSet]` to **both** the `WorkoutRepositoryProviding` protocol and the `WorkoutRepository` concrete class.
  - `FakeWorkoutRepository` in tests must implement it too.
  - Query `workout_sets` filtered by `session_id`, ordered by `exercise_id` then `set_number`.
  - Map through `ErrorMapper.map(error, context:)`.
  - Return `[]` (not nil) when no sets exist.
- [ ] Create `Gymbros/Data/Services/StreakService.swift` as a pure Swift struct with no I/O.
  - `func streak(from sessions: [WorkoutSession], today: Date = .now) -> Int`
  - Use `Calendar(identifier: .iso8601)` — **never** `Calendar.current` (locale-dependent first weekday makes tests non-deterministic).
  - Group by `.yearForWeekOfYear` + `.weekOfYear` using that calendar.
  - Current week never counts or breaks streak.
  - Return 0 when result < 2.
- [ ] Create `GymbrosTests/StreakServiceTests.swift` using Swift Testing.
  - Test: zero sessions → 0.
  - Test: sessions only in current week → 0.
  - Test: one prior week → 0 (below threshold).
  - Test: two consecutive prior weeks → 2.
  - Test: five consecutive prior weeks → 5.
  - Test: gap two weeks ago → 0 (count=1, below threshold).
  - Test: incomplete sessions excluded.
  - Test: year boundary (Dec week into Jan).
- [ ] Run targeted tests.
- [ ] Update `CURRENT STATUS` and handoff notes.

**Verification command:**
```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/StreakServiceTests
```

**Handoff notes:** Add when complete.

---

## Task 2: TodayViewModel + Tests

**Owner:** ViewModel worker. Parallel-safe after Task 0. Depends on Task 1 shapes being locked (not necessarily compiled).

**Parallel-safe ownership:** Own `TodayViewModel` and its tests. Do not touch SwiftUI view files, History ViewModels, or `Localizable.xcstrings`.

**Files likely touched:**
- `Gymbros/Presentation/Today/TodayViewModel.swift` (new)
- `GymbrosTests/TodayViewModelTests.swift` (new)

**Forbidden files:**
- `Gymbros/Presentation/Today/TodayView.swift`
- `Gymbros/Presentation/History/*`
- `Gymbros/App/RootView.swift`
- `Gymbros/Resources/Localizable.xcstrings`
- `Gymbros/Data/Repository/WorkoutRepository.swift`

- [ ] Create `Gymbros/Presentation/Today/TodayViewModel.swift`.
  - `@MainActor @Observable final class TodayViewModel`.
  - Locked init: `init(programRepository: ProgramRepositoryProviding? = nil, workoutRepository: WorkoutRepositoryProviding? = nil)` — default `nil` → concrete fallback. Tests inject `FakeProgramRepository` / `FakeWorkoutRepository`.
  - `var state: ViewState<TodayData>`, `var transientError: AppError?`.
  - `func load() async` and `func refresh() async`.
  - Call `fetchActive()` and `fetchHistory(limit: 50)` concurrently (use `async let` or `withTaskGroup`).
  - Pass completed sessions to `StreakService.streak(from:)`.
  - Derive `nextDay`: sort active program days by `dayOrder`; find the day whose `dayOrder` immediately follows the most-recently-completed session's `programDayId`. **Fallback rule (locked):** if the most-recent completed session has a `nil` `programDayId` OR its id is not among the active program's days, use the first day (lowest `dayOrder`). Wrap around after the last day. First day if no history.
  - `fetchActive()` is fully hydrated — `nextDay.exercises` is populated; no extra fetch needed for exercise preview.
  - Set `isWelcomeBack = true` when history is empty (and program exists) or last session ≥7 days ago.
  - Map repository errors through `AppError`/`ViewState`.
- [ ] Define `TodayData` struct in the same file or a shared file — accessible from both ViewModel and mock data.
- [ ] Create `GymbrosTests/TodayViewModelTests.swift` with mock repositories.
  - No active program → `.success` with nil nextDay.
  - Active program, no history → nextDay is first day.
  - Active program, one session → nextDay wraps correctly.
  - Last session > 7 days ago → `isWelcomeBack == true`.
  - Last session within 7 days → `isWelcomeBack == false`.
  - Repository error → `.error`.
- [ ] Run targeted tests.
- [ ] Update `CURRENT STATUS` and handoff notes with concrete VM initializer signature.

**Verification command:**
```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/TodayViewModelTests
```

**Handoff notes:** Add when complete.

---

## Task 3: HistoryViewModel + SessionDetailViewModel + Tests

**Owner:** ViewModel worker. Parallel-safe after Task 0. Depends on Task 1 `fetchSets` shape being locked.

**Parallel-safe ownership:** Own both history ViewModels and their tests. Do not touch SwiftUI view files, TodayViewModel, or `Localizable.xcstrings`.

**Files likely touched:**
- `Gymbros/Presentation/History/HistoryViewModel.swift` (new)
- `Gymbros/Presentation/History/SessionDetailViewModel.swift` (new)
- `GymbrosTests/HistoryViewModelTests.swift` (new)

**Forbidden files:**
- `Gymbros/Presentation/History/HistoryView.swift`
- `Gymbros/Presentation/History/SessionDetailView.swift`
- `Gymbros/Presentation/Today/*`
- `Gymbros/App/RootView.swift`
- `Gymbros/Resources/Localizable.xcstrings`
- `Gymbros/Data/Repository/WorkoutRepository.swift`

- [ ] Create `Gymbros/Presentation/History/HistoryViewModel.swift`.
  - `@MainActor @Observable final class HistoryViewModel`.
  - Locked init: `init(workoutRepository: WorkoutRepositoryProviding? = nil, programRepository: ProgramRepositoryProviding? = nil)`.
  - `var state: ViewState<HistoryData>`, `var transientError: AppError?`.
  - `func load() async`.
  - Calls `WorkoutRepository.fetchHistory(limit: 50)` and `ProgramRepository.fetchAll()` **concurrently**.
  - Flattens every program's `.days` into `dayNames: [UUID: String]` (programDayId → day name string).
  - Empty sessions → `.empty`; sessions present → `.success(HistoryData(sessions:dayNames:))`.
- [ ] Define `HistoryData` struct with `sessions: [WorkoutSession]` and `dayNames: [UUID: String]`, accessible from ViewModel and mock.
- [ ] Create `Gymbros/Presentation/History/SessionDetailViewModel.swift`.
  - `@MainActor @Observable final class SessionDetailViewModel`.
  - Locked init: `init(session: WorkoutSession, workoutRepository: WorkoutRepositoryProviding? = nil, exerciseRepository: ExerciseRepositoryProviding? = nil)`.
  - `var state: ViewState<SessionDetailData>`, `var transientError: AppError?`.
  - `func load() async` — calls `WorkoutRepository.fetchSets(sessionId:)` and `ExerciseRepository.fetchAll()` **concurrently**.
  - Builds `exerciseLookup: [UUID: Exercise]` using `ProgramViewModelSupport.exerciseLookup(from:)`. Falls back to empty dict on exercise-fetch failure.
- [ ] Define `SessionDetailData` struct with `session: WorkoutSession`, `sets: [WorkoutSet]`, `exerciseLookup: [UUID: Exercise]` (non-optional).
- [ ] Create `GymbrosTests/HistoryViewModelTests.swift`.
  - No sessions → `.empty`.
  - Sessions returned → `.success`.
  - Session with known `programDayId` → `dayNames` resolves correct day name string.
  - Session with `nil` or unknown `programDayId` → `dayNames` lookup misses; view renders `history.session.custom`.
  - Session with no sets → `.success` with empty set list.
  - Session with sets → sets present in data.
  - Repository error → `.error`.
- [ ] Run targeted tests.
- [ ] Update `CURRENT STATUS` and handoff notes.

**Verification command:**
```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/HistoryViewModelTests
```

**Handoff notes:** Add when complete.

---

## Task 4: Tab Navigation Shell

**Owner:** Integration worker. Sequential after Task 0. Can run in parallel with Tasks 1–3 because it only touches `RootView.swift`.

**Parallel-safe ownership:** Own `RootView.swift` TabView shell only. Do not implement Today/History views or their ViewModels.

**Files likely touched:**
- `Gymbros/App/RootView.swift`

**Forbidden files:**
- `Gymbros/Presentation/Today/*`
- `Gymbros/Presentation/History/*`
- `Gymbros/Data/Repository/*`
- `Gymbros/Resources/Localizable.xcstrings`

- [ ] Replace the authenticated branch in `RootView` (currently `ProgramListView`) with a `TabView`.
  - Tab 0 — Today: `NavigationStack { TodayView() }` with `Label("today.title", systemImage: "house")`.
  - Tab 1 — Programs: `NavigationStack { ProgramListView() }` with `Label("programs.title", systemImage: "list.bullet")` (key already exists).
  - Tab 2 — History: `NavigationStack { HistoryView() }` with `Label("history.title", systemImage: "clock")`.
  - Today is selected by default (`.tabItem` order = Today first).
- [ ] Use placeholder views (`Text("Today")`, `Text("History")`) if the real views are not yet compiled. Real wiring happens in Task 8.
- [ ] Ensure the unauthenticated branch is untouched (still shows `SignInView`).
- [ ] Build check.
- [ ] Update `CURRENT STATUS`.

**Verification command:**
```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

**Handoff notes:** Add when complete.

---

## Task 5: TodayView + Mock + Previews

**Owner:** UI worker. Parallel-safe after Task 0.

**Parallel-safe ownership:** Own `TodayView.swift` and `TodayMockData.swift`. Do not wire to real ViewModel runtime — use mock/sample data for previews. Do not touch History views, WorkoutRepository, or `Localizable.xcstrings`.

**Files likely touched:**
- `Gymbros/Presentation/Today/TodayView.swift` (new)
- `Gymbros/Presentation/Today/TodayMockData.swift` (new)

**Forbidden files:**
- `Gymbros/Presentation/Today/TodayViewModel.swift`
- `Gymbros/Presentation/History/*`
- `Gymbros/App/RootView.swift`
- `Gymbros/Data/Repository/*`
- `Gymbros/Resources/Localizable.xcstrings`

- [ ] Build `TodayView` with loading, error, and success states.
- [ ] Success layout:
  - Greeting text by time-of-day.
  - Optional welcome-back banner (when `isWelcomeBack == true`): positive tone, no warning styling.
  - No-program empty state: "Ready when you are." + CTA to Programs tab.
  - Next-workout card: day name, exercise preview, last-workout date in `.secondary`, optional streak badge (`streakWeeks >= 2`).
  - Start button (primary `.blue` tint), min 48pt tap target, navigates to `WorkoutSessionScreen(programDayId:)`.
- [ ] Anti-guilt copy rules enforced: no negative copy, no fire/broken emoji, no pressure language.
- [ ] Use localization keys from spec (e.g. `today.greeting.morning`, `today.start_cta`).
- [ ] Create `TodayMockData.swift` with `#if DEBUG` sample data for all preview states.
- [ ] Add previews for: loading, error, no-program empty, has-program-no-history, has-program-with-streak, welcome-back-banner.
- [ ] Accessibility labels on the Start button and streak badge.
- [ ] Build check.
- [ ] Update `CURRENT STATUS` and handoff notes with view initializer / action callback signatures.

**Verification command:**
```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

**Handoff notes:** Add when complete.

---

## Task 6: HistoryView + SessionDetailView + Mock + Previews

**Owner:** UI worker. Parallel-safe after Task 0.

**Parallel-safe ownership:** Own `HistoryView.swift`, `SessionDetailView.swift`, `HistoryMockData.swift`. Do not wire to real ViewModels — use mock data for previews. Do not touch Today views, WorkoutRepository, or `Localizable.xcstrings`.

**Files likely touched:**
- `Gymbros/Presentation/History/HistoryView.swift` (new)
- `Gymbros/Presentation/History/SessionDetailView.swift` (new)
- `Gymbros/Presentation/History/HistoryMockData.swift` (new)

**Forbidden files:**
- `Gymbros/Presentation/History/HistoryViewModel.swift`
- `Gymbros/Presentation/History/SessionDetailViewModel.swift`
- `Gymbros/Presentation/Today/*`
- `Gymbros/App/RootView.swift`
- `Gymbros/Data/Repository/*`
- `Gymbros/Resources/Localizable.xcstrings`

- [ ] Build `HistoryView` with loading, empty, error, and success states.
  - Session row (locked layout): **headline** = program day name from `HistoryData.dayNames[session.programDayId]`. When `programDayId` is `nil` or missing from the lookup, render the localized `history.session.custom` key ("Custom workout"). **Subheadline** = `workoutDisplayString` date + duration (e.g. "42 min").
  - Empty state: `history.empty` key ("No workouts yet. Your first one is waiting.") — no judgment copy.
  - Tap navigates to `SessionDetailView`.
- [ ] Build `SessionDetailView` with loading, error, and success states.
  - Title: session date. Subheader: total duration.
  - Sets grouped per exercise: exercise name from `SessionDetailData.exerciseLookup` as section header. When a set's `exerciseId` is not in the lookup, use the localized `session.exercise.unknown` key ("Exercise") as the fallback header. Then rows of set# / weight / reps / optional RPE.
  - Read-only: no inputs, no delete, no add-set affordance.
- [ ] Create `HistoryMockData.swift` with `#if DEBUG` sample data.
- [ ] Add previews for: HistoryView loading / empty / error / success (multiple sessions); SessionDetailView loading / error / success.
- [ ] Build check.
- [ ] Update `CURRENT STATUS` and handoff notes.

**Verification command:**
```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

**Handoff notes:** Add when complete.

---

## Task 7: Localization

**Owner:** Localization worker. Parallel-safe after Task 0.

**Parallel-safe ownership:** Own `Localizable.xcstrings`. Coordinate key names from spec and Tasks 5/6 handoff when available.

**Files likely touched:**
- `Gymbros/Resources/Localizable.xcstrings`

**Forbidden files:**
- All Swift source files in `Presentation/Today/` and `Presentation/History/`.
- `Gymbros/Data/Repository/WorkoutRepository.swift`

- [x] Add `today.*` keys with Thai and English: `today.title`, `today.greeting.morning`, `today.greeting.afternoon`, `today.greeting.evening`, `today.next_workout.title`, `today.start_cta`, `today.streak.weeks`, `today.last_workout`, `today.welcome_back`, `today.empty.no_program`, `today.empty.programs_cta`.
- [x] Add `history.*` keys: `history.title`, `history.empty`, `history.session.duration`, `history.session.custom` ("Custom workout" / "เวิร์กเอาท์ทั่วไป").
- [x] Add `session.*` keys: `session.title` (or use date formatting directly), `session.duration`, `session.set.weight_reps`, `session.set.rpe`, `session.exercise.unknown` ("Exercise" / "ท่าออกกำลังกาย").
- [x] Add `accessibility.*` keys: `accessibility.today.start`, `accessibility.today.streak`, `accessibility.history.session_row`.
- [x] Verify every new key has both English and Thai values.
- [x] Search `Presentation/Today/` and `Presentation/History/` for hardcoded user-facing strings and replace with keys (if Task 5/6 views are available).
- [x] Update `CURRENT STATUS`.

**Verification:** Inspect string catalog; spot-check English and Thai for completeness.

**Handoff notes:** Complete in `worktree-s04-task7-localization`.
- Added canonical keys and SwiftUI interpolation-shaped variants for formatted strings, including `today.streak.weeks %lld`, `today.last_workout %@`, `accessibility.today.start %@`, `accessibility.today.streak %lld`, `history.session.duration %lld`, `session.duration %lld`, `session.set.weight_reps %@ %lld`, `session.set.rpe %@`, and `accessibility.history.session_row %@ %lld`.
- Verified JSON with `jq empty Gymbros/Resources/Localizable.xcstrings`.
- Verified required keys have both English and Thai values with `jq` (`all-present`).
- `Presentation/Today/` and `Presentation/History/` were not present in this isolated base branch, so no Swift source replacements were possible in Task 7.

---

## Task 8: Wire + Verify

**Owner:** Final integration worker. Sequential after Tasks 1–7 are complete or explicitly handed off.

**Files likely touched:**
- `Gymbros/App/RootView.swift`
- `Gymbros/Presentation/Today/TodayView.swift`
- `Gymbros/Presentation/History/HistoryView.swift`
- `Gymbros/Presentation/History/SessionDetailView.swift`
- `Gymbros/Resources/Localizable.xcstrings`
- Tests as needed.

**Forbidden files:** None within Sprint 4 scope, but preserve unrelated user changes and inspect diffs before editing.

- [ ] Review Tasks 1–7 handoff notes.
- [ ] Connect `TodayView` to concrete `TodayViewModel`.
- [ ] Connect `HistoryView` to concrete `HistoryViewModel`.
- [ ] Connect `SessionDetailView` to concrete `SessionDetailViewModel`.
- [ ] Ensure `RootView` TabView uses the real views (not placeholders from Task 4).
- [ ] Ensure `TodayView` Start CTA navigates to `WorkoutSessionScreen(programDayId:)` correctly.
- [ ] Remove or preview-scope mock-only runtime paths.
- [ ] Confirm all user-facing strings use localization keys (grep for hardcoded strings).
- [ ] Confirm all visible errors use localized `AppError` UI (`.transientErrorAlert` or similar).
- [ ] Confirm no "streak broken", "missed", "failed", or shaming copy exists anywhere in Sprint 4 files.
- [ ] Run color grep:
  ```bash
  rg -n "gymAccent|gymPurple|gymAccentText|Color\\(\"AccentColor\"|Color\\(\"GymPurple\"|Color\\(red:|#[0-9A-Fa-f]{6}" Gymbros/ --type swift
  ```
  Expect zero active app UI hits.
- [ ] Run full test suite.
- [ ] Manual smoke test (follow spec §10).
- [ ] Check `git diff` for accidental secrets or unrelated changes.
- [ ] Update `CURRENT STATUS`: mark Sprint 4 complete if verified, list test results, last commit SHA if committed, and next step (Sprint 5 — Settings).

**Verification command:**
```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'
```

**Handoff notes:** Add when complete.

---

## Acceptance Checklist

- [ ] Today tab appears by default after sign-in.
- [ ] TodayView shows appropriate greeting by time-of-day.
- [ ] No active program → "Ready when you are" empty state with Programs CTA.
- [ ] Active program → next-workout card with correct next day.
- [ ] Start CTA navigates to the workout logger for the correct program day.
- [ ] Welcome-back banner appears after 7+ days idle; no negative copy.
- [ ] Streak badge shows only when ≥2 consecutive prior weeks logged.
- [ ] No "streak broken", "missed", "failed", or shaming copy in any screen.
- [ ] Programs tab shows existing ProgramListView correctly.
- [ ] History tab shows completed sessions newest-first.
- [ ] Empty history → encouraging non-shaming empty state.
- [ ] Tap session row → SessionDetailView with read-only set detail.
- [ ] SessionDetailView shows sets grouped per exercise with no edit affordance.
- [ ] All visible strings are localized in Thai and English.
- [ ] No raw SDK/database errors reach SwiftUI.
- [ ] Automated tests pass (StreakService, TodayViewModel, HistoryViewModel, SessionDetailViewModel).
- [ ] Manual smoke test passes on `iPhone 17e`.
