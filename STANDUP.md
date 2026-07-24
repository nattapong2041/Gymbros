# STANDUP — Session Handoff

> Update this file at the start and end of every session (date, HEAD SHA, last-done, next-up, open follow-ups).

---

**Last updated:** 2026-07-24 | HEAD `3d204cc` (Sprint 6.1 — Post-Launch Feature Wave, 4 of 5 features implemented) | Branch `main` (55 commits ahead of `origin/main`, not yet pushed)

---

## Where we are

Sprints 1–6 and S05p fully implemented and committed. Local-first workout sessions and S06 were committed together at `e1859b6`. S06 manual smoke is still genuinely pending — requires editing a `workout_sessions.ended_at` in Supabase to simulate a 14+ day gap. Sprint 6.1 (Post-Launch Feature Wave) is now implemented end-to-end for 4 of its 5 features (RPE UX Simplification, Skip a Day, Training Phase Setting, Progressive Overload Advisor) — Substitute remains unapproved and out of scope. Sprint 6.1's own manual smoke is also pending; see "Next up" below.

| Sprint | Name | Status |
|--------|------|--------|
| S01 | Foundation + Data | complete |
| S02 | Custom Program Builder | complete |
| S03 | Logger + Timer | complete |
| S04 | Today + History + Navigation + Anti-Guilt UX | complete |
| S05 | Settings | complete |
| **S05p** | **Phase 1 Polish** | **implemented, manual smoke passed, committed** |
| **S06** | **Next Best Session v1 / Smart Comeback** | **implemented, committed at `e1859b6` — manual smoke still pending** |
| **local-first** | **Session upload only on Finish** | **implemented, committed at `e1859b6`** |
| **S06.1** | **Post-Launch Feature Wave (RPE, Skip Day, Training Phase, Overload Advisor)** | **implemented, committed through `3d204cc` — manual smoke pending; Substitute not yet approved** |

---

## Last session did

- Follow-up to the RPE feature (commit `59babc3`): expanded the 3-option Easy/Just right/Hard picker to 4 bands (Easy/Moderate/Hard/All Out) covering the full 1-10 RPE scale, modeled on Apple Workout's "Rate Your Effort" screen. A single tap on a band still picks a sensible default (fast path, unchanged speed from before); a new "Choose exact number..." submenu drills into the exact 1-10 value grouped by band, each section labeled with a reps-in-reserve description ("Challenging, a couple reps left" etc.) so users learn what to pick instead of just getting more raw numbers. Deliberately kept as an inline per-set `Menu` rather than Apple's full-screen sheet, since this is asked many times per workout, not once per session. `HowDidThatFeel.band(for:)` replaces `nearest(to:)`; legacy stored values (6.0/7.5/9.0 from the prior 3-point scale) now correctly re-bucket one tier higher since they sit on the true 1-10 scale — intentional. `rpe: Double?` and both downstream range-based services untouched. Verified: full build + full `GymbrosTests` suite green, `jq` valid, `git diff --check` clean.

- Implemented Sprint 6.1 — Post-Launch Feature Wave (4 of 5 features), via subagent-driven-development directly on `main`, 18 tasks, commits `07ceda7`..`3d204cc`:
  - **RPE UX Simplification** (Tasks 1-6): replaced the raw 1.0-10.0 `SetRowView`/`SessionDetailView` RPE menus with the existing Easy/Just right/Hard scale (`HowDidThatFeel`); added `HowDidThatFeel.nearest(to:)` bucketing for legacy stored values; removed comeback mode's now-redundant `HowDidThatFeelPicker` end-of-exercise sheet and `applyFeedback`/`hasCompletedSets`, since per-set input already captures the same three values everywhere.
  - **Skip a Day** (Task 7): `TodayView` gained a "Change day" menu next to the Start CTA, listing every other day in the active program; picking a day reuses the same `comebackCard`/`nextWorkoutCard` render functions with a different `ProgramDay`. Review caught that `TodayView` is a permanent tab root (never recreated), so the picked day would have silently outlived "this session only" — fixed with `.onChange(of: nextDay?.id) { selectedDay = nil }`.
  - **Training Phase Setting** (Tasks 8-11): added `Profile.trainingPhase: TrainingPhase?` (bulk/cut/maintain) with a `profiles.training_phase` migration applied to the live `gymbros` Supabase project after explicit approval; added a Settings row mirroring the weight-unit toggle exactly.
  - **Progressive Overload Advisor** (Tasks 12-17): new `StallDetector` service (same top-set weight across 4 qualifying sessions, RPE ≤8.0 gate); new local `OverloadAdvisorSnoozeStore` (14-day snooze, `UserDefaults`-backed); new `OverloadAdvisorCardView` on Today (normal mode only, never alongside the comeback card, suppressed when `trainingPhase` is cut/maintain); `TodayViewModel` now also fetches sets on normal days (bounded to 4 sessions) to feed the detector.
  - **Substitute** (feature 5) intentionally excluded — not yet approved, per the design docs.
  - Every task went through implementer → reviewer → (fix + re-review if needed); two tasks needed one fix round each (Skip a Day's `selectedDay` reset; one Overload Advisor test's missing isolated fakes).
  - **Final whole-branch review caught a real functional bug the per-task reviews couldn't see**: `TodayViewModel.fetchBudgetedSets` only fetched sets for the 4 most *recent* sessions on normal days, but `StallDetector` needs 4 *qualifying* (same-exercise) sessions — on any multi-day program (Upper/Lower, PPL, the norm for real users), the 4 most recent sessions rarely all share one exercise, so the Overload Advisor could essentially never fire. First fixed by reusing the wider 14-session comeback-baseline budget on every day (`fetchBudgetedSets`, commit `f095b0b`), plus a new regression test (`stalledExerciseDetectedAcrossInterleavedMultiDayRotation`).
  - **Follow-up redesign requested after that fix, grounded in research** (commit `4673aa6`): a session-count rule is frequency-agnostic — it took a 3x/week lifter under 2 weeks to accumulate the same "evidence" an infrequent lifter took a month to gather, and it let progression earlier in a long lookback window mask a genuine current plateau (e.g. 70→80kg then holding 80kg for 3 sessions would have failed the old "all 4 equal" check). Researched how real coaching evaluates this — RP-style mesocycles and Stronger By Science both converge on **4-6 calendar weeks** as the block over which a plateau is judged, not a fixed rep-through-rotation count; deloads in practice cluster around every ~5.6 weeks per a cross-sectional athlete survey. Redesigned `StallDetector.isStalled` to require **≥3 qualifying sessions within a rolling 35-day window**, checking weight equality only across the *most recent* qualifying sessions (not every qualifying session ever seen in the window) so earlier progression no longer masks a current stall. `fetchBudgetedSets` now fetches by calendar cutoff on normal days (capped at 30 sessions defensively) instead of a guessed row count — this also makes the original fetch bug structurally impossible to reintroduce, since "how many sessions do I need" is no longer a question the fetch layer has to guess at. Updated `today.overload_advisor.body` copy since it no longer describes a fixed count. Comeback-day baseline tracking untouched (looks across an arbitrary historical gap, not a rolling window, so a calendar cutoff doesn't fit it).
  - Verified: full build `** BUILD SUCCEEDED **`, full `GymbrosTests` suite `** TEST SUCCEEDED **` (including a new `StallDetectorTests` suite rewritten for the window-based rules), `jq empty Gymbros/Resources/Localizable.xcstrings` valid, `git diff --check` clean.
  - Environment note discovered this session: this machine's simulators are `iPhone 17`, `iPhone 17 Pro`, `iPhone 17 Pro Max` — **no `iPhone 17e`**, despite CLAUDE.md/prior plans specifying it. Used `iPhone 17` for every build/test command this session (user-confirmed). `GymbrosUITestsLaunchTests` and the aggregate `xcodebuild test` result occasionally hit a transient "Simulator device failed to launch... Busy" clone-contention flake unrelated to code; always confirmed via individual test-case output and/or a clean retry.
  - Plan + spec: `.claude/sprints/S06.1-post-launch-feature-wave/{spec.md,plan.md}`.
  - Next: run the combined manual smoke checklist below, then either pursue Substitute's approval or start Sprint 7.

- Implemented local-first workout sessions (orphaned-row fix):
  - `WorkoutSessionViewModel.start()` no longer calls any repository — session is now built locally as a `WorkoutSession(id: UUID(), ...)` with client-generated id. Added `currentUserId: @MainActor () -> UUID?` injection (defaults to `AuthService.shared.currentUser?.id`).
  - `WorkoutRepositoryProviding` protocol: removed `createSession(programDayId:startedAt:)`, added `func insertSession(_ session: WorkoutSession) async throws`.
  - `WorkoutSessionInsertPayload` extended with `id: UUID` and `endedAt: Date?` (keeps omitting `created_at` so the DB owns it).
  - `finishSession()` now inserts the completed session (endedAt set) first, then uploads sets one-by-one. On session-insert failure: saves backup, surfaces error, returns (nothing in DB). On any set-upload failure: best-effort rollback `try? deleteSession(id:)`, saves backup, surfaces original error (rollback failure does not mask it). Backup cleared only after all uploads succeed.
  - Back-button and discard paths unchanged — they were already local-only; no DB write ever reaches them now.
  - All three `FakeWorkoutRepository` fakes (WorkoutSessionViewModelTests, TodayViewModelTests, HistoryViewModelTests) updated to `insertSession` protocol.
  - Tests updated: `startSuccessCreatesSessionAndInitialRows` asserts no remote insert at start; `workoutStartStartsLiveActivityWithActiveCurrentSet` uses `data.session.id` not fake's preset id; `uploadConflictUpdatesExistingSetAndAllowsFinish`, `finishSessionSkipsInvalidSets`, `finishSessionUploadsAllCompletedSets`, `finishClearsBackupWhenCompletionSucceeds` all check `insertedSessions` not `completedSessions`; `finishDoesNotClearBackupWhenCompletionFails` uses `insertSessionError`; new test `finishSetUploadFailureRollsBackSessionAndKeepsBackup` asserts session rollback on set-upload failure.
  - Verified:
    `xcodebuild build ...` → `** BUILD SUCCEEDED **`
    `xcodebuild test ... -only-testing:GymbrosTests/WorkoutSessionViewModelTests -only-testing:GymbrosTests/TodayViewModelTests -only-testing:GymbrosTests/HistoryViewModelTests` → `** TEST SUCCEEDED **`
    `xcodebuild test ...` (full suite) → `** TEST SUCCEEDED **`
  - HEAD still `606d9d7` — commit pending.

- Implemented Sprint S06 — Next Best Session v1 / Smart Comeback (full end-to-end):
  - Added `SmartSessionAdvisor` (5 day bands: 0–13 normal, 14–20/21–41/42+ comeback with weight multipliers 0.9/0.8/0.6 and −1 set delta).
  - Added `ComebackRampService` (exit / holdAddRep / increase+15% / increase+10% / decrease−5% RPE-gated decisions).
  - Added `HowDidThatFeel` enum (easy=6.0 / justRight=7.5 / hard=9.0 RPE).
  - Added `ProgressiveOverloadEngine` (60-day window, ≥2 sessions, +2.5 kg on RPE ≤7.0, hold 7.5–8.0, nil otherwise).
  - Added `AnalyticsTracking` protocol + `NoopAnalytics` / `DebugConsoleAnalytics` seam with 4 comeback events.
  - Added `NextBestSessionEngine` — persistent state machine: open-ended gap detection (≥14 days), per-exercise baseline/current tracking, weight-based exit (current ≥ baseline && RPE ≤7.5), bounded exit (4 post-gap sessions), ramp derivation, overload hints in normal mode.
  - Added `TodayRecommendation` struct (`mode: .normal | .comeback`, `rampPreview`, `overloadHints`, `gapDays`, `reasonKey`).
  - Extended `WorkoutRepository` with `updateSets(ids:rpe:)` — single PATCH for RPE backfill.
  - Extended `TodayViewModel` with `NextBestSessionEngine` + analytics injection; fetches sets only when gap candidate detected (D6 budget).
  - Extended `WorkoutSessionViewModel` with comeback support: adjusted set counts, D3 weight chain, baseline reference rows, `applyFeedback`, `checkBaselineRegained` (haptic + analytics, fires once), `finishSession` comeback event.
  - Added `ComebackCardView` (bilingual TH+EN, reason line, ramp hint, Start CTA ≥48pt).
  - Added `EasingBackBadge` (capsule, arrow.uturn.backward, tertiarySystemFill).
  - Added `HowDidThatFeelPicker` (sheet, medium detent, 3 feel buttons + Skip).
  - Wired Today comeback card, WorkoutSessionScreen feedback picker, WorkoutExercisePageView easing-back badge + overload hint, baseline row format (D5 key).
  - Added 21 localization keys (en + th): today.comeback.*, comeback.reason.*, workout.comeback.*, workout.overload.hint, accessibility.*.
  - Tests: SmartSessionAdvisorTests, ComebackRampServiceTests, ProgressiveOverloadEngineTests, NextBestSessionEngineTests (incl. persistence, old-gap guard, bounded exit), WorkoutRepositoryPayloadTests, TodayViewModelTests (3 new), WorkoutSessionViewModelTests (6 new comeback tests).
  - Verified:
    `git diff --check` — clean
    Focused suite `xcodebuild test ... -only-testing:GymbrosTests/SmartSessionAdvisorTests ...` — all pass
    Full suite `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'` — `** TEST SUCCEEDED **`
    Build — `** BUILD SUCCEEDED **`

- Marked S05p manual smoke as passed after user verification:
  - Rest notification fires after backgrounding during rest, and notification tap-back opens the active exercise page.
  - Whole-workout Live Activity appears on workout start/restore, shows elapsed time, switches to rest countdown, and shows Ready/Go state after rest completes.
  - Persistent in-app bottom workout widget remains visible across tabs, resumes the active exercise page, floats above the tab/navigation bar without blocking controls, and supports cancel/confirm stop behavior while preserving the resumable backup.
  - Last-session mixed-load rows, responsive workout table columns, global keyboard dismissal, timer Ready state, and History duration editing passed manual smoke.
  - Verified final post-smoke checks:
    `jq empty Gymbros/Resources/Localizable.xcstrings`
    `jq empty GymbrosWidgets/Localizable.xcstrings`
    `plutil -lint Gymbros/Info.plist`
    `plutil -lint GymbrosWidgets/Info.plist`
    `git diff --check`
    `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'`
    `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`
  - Next up: commit S05p, then start Sprint 6 planning.

- Implemented S05p follow-up replacing workout exit confirmation with a persistent in-app resume widget:
  - Lock Screen Live Activity now presents three stable content lines: workout status, workout name, and weight/set/reps.
  - Activity state now carries `workoutName` and per-row `weightText`, so the widget can render the workout name separately from the prescription.
  - Back from `WorkoutSessionScreen` now saves the active-session backup and dismisses without ending Live Activity/Dynamic Island or cancelling rest notifications.
  - Root tab screens now show a persistent bottom active-workout widget while a resumable backup exists and the workout screen is not visible.
  - The bottom widget now matches the Hevy-style reference as a compact two-line floating pill above the tab/navigation bar.
  - The pill now uses SwiftUI Liquid Glass on iOS 26 with a system-material fallback, semantic colors, SF Symbols, and standard fonts; visible copy is status/time plus exercise name.
  - The pill is now a bottom overlay with no explicit shadow and a visual upward offset, so it floats above the tab bar without adding a transparent hit-test area over tab labels/buttons.
  - Left/center tap routes through the existing Today workout deep link to resume the active workout exercise page.
  - Right red trash shows a localized confirmation; confirm hides the widget, cancels rest notifications, ends Live Activity/Dynamic Island, and keeps the active backup resumable.
  - Added Thai and English copy for the bottom widget stop flow and focused test coverage for compact status + suppression behavior.
  - Verified:
    `jq empty Gymbros/Resources/Localizable.xcstrings`
    `jq empty GymbrosWidgets/Localizable.xcstrings`
    `git diff --check`
    `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/WorkoutSessionViewModelTests -only-testing:GymbrosTests/ActiveSessionBackupTests`
    `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`
    Latest Liquid Glass / above-tab-bar placement check:
    `jq empty Gymbros/Resources/Localizable.xcstrings`
    `git diff --check`
    `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`

- Implemented S05p whole-workout Live Activity follow-up:
  - Expanded the ActivityKit payload from rest-only timer fields to full workout state: active/resting/ready phase, `workoutStartedAt`, current work, next work, and rest countdown dates.
  - Live Activity now starts on workout start/restore, updates on draft reps, set completion, rest start, rest completion, stop/skip rest, page changes, exercise finish, and ends on workout finish/discard.
  - Lock Screen/Dynamic Island show elapsed workout time, current or next exercise, set/reps, rest countdown while resting, and a ready/work icon + copy when rest completes.
  - Dynamic Island tap-back still uses the existing workout deep link, now using the mutable current/next `programExerciseId` from Activity state.
  - Rest-complete notification sound remains the default iOS notification sound; tests assert `.sound` authorization and non-nil notification sound.
  - Added Thai and English app/widget copy for Live Activity workout/reps/elapsed/work summary labels.
  - Updated S05p `spec.md` and `plan.md` with the new follow-up scope and verification.
  - Verified:
    `plutil -lint Gymbros/Info.plist`
    `plutil -lint GymbrosWidgets/Info.plist`
    `jq empty Gymbros/Resources/Localizable.xcstrings`
    `jq empty GymbrosWidgets/Localizable.xcstrings`
    `git diff --check`
    `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/RestTimerNotificationSchedulerTests -only-testing:GymbrosTests/WorkoutSessionViewModelTests`
    `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'`
    `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`

- Fixed mixed-load last-session workout references:
  - `LastSessionReference` now preserves per-set weight/reps summaries instead of storing only the first weight and a reps list.
  - `WorkoutExercisePageView` keeps identical-weight sessions compact, but renders mixed-load history set-by-set, e.g. `59 × 10 -> 65 × 8 -> 65 × 5`.
  - Last-session rows can now wrap to two caption lines before truncating, so detailed history has room on smaller screens.
  - Unit changes now convert every stored last-session set weight, not just the first set.
  - Added Thai and English copy for the detailed last-session format.
  - Added regression coverage for the exact `59kg x 10 -> 65kg x 8 -> 65kg x 5` case.
  - Verified:
    `jq empty Gymbros/Resources/Localizable.xcstrings`
    `git diff --check`
    `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/LastSessionLookupServiceTests -only-testing:GymbrosTests/WorkoutSessionViewModelTests`

- Implemented History workout deletion:
  - Added `WorkoutRepository.deleteSession(id:)` for deleting `workout_sessions`; existing FK cascade removes associated `workout_sets`.
  - Added `HistoryViewModel.deleteSession(_:)` to remove deleted sessions from current state, move to empty state when the last row is deleted, and surface failures through `AppError`.
  - Added trailing swipe delete on History rows with a destructive localized confirmation alert.
  - Added Thai and English delete-confirmation copy.
  - Verified:
    `jq empty Gymbros/Resources/Localizable.xcstrings`
    `git diff --check`
    `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/HistoryViewModelTests`

- Implemented S05p follow-up fixes from manual smoke feedback:
  - Workout logger rows now measure available width and compute responsive columns for Set, kg/lb, Reps, RPE, and Done, so headers align with row values across iPhone and iPad widths.
  - Rest timer completion now freezes the in-app timer at zero, shows Ready copy, and marks the Live Activity complete so Lock Screen/Dynamic Island show Ready/Go messaging instead of counting upward.
  - Added app/widget Thai and English copy for timer Ready states.
  - Verified:
    `jq empty Gymbros/Resources/Localizable.xcstrings`
    `jq empty GymbrosWidgets/Localizable.xcstrings`
    `git diff --check`
    `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/WorkoutSessionViewModelTests -only-testing:GymbrosTests/RestTimerNotificationSchedulerTests`

- Implemented earlier S05p follow-up fixes from manual smoke feedback:
  - Rest timer now requests local-notification authorization whenever a rest starts, covering the normal foreground-start/background-during-rest flow.
  - Refined rest notification copy to "Ready for your next set" / "Rest is over. Time to lift." with Thai translations.
  - `AppDelegate` now presents rest notifications when the app is foregrounded too, while keeping notification tap-back routed to the active workout exercise page.
  - Added root-level `.dismissKeyboardOnTap()` so tapping outside text fields dismisses the keyboard app-wide.
  - Removed repeated kg/lb labels from active workout set rows and removed the weight-unit suffix from the last-session reference row text.
  - History duration display now rounds minutes so a saved 60-minute workout does not render as 59 minutes because of sub-second date precision.
  - Verified:
    `jq empty Gymbros/Resources/Localizable.xcstrings`
    `git diff --check`
    `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/RestTimerNotificationSchedulerTests -only-testing:GymbrosTests/WorkoutSessionViewModelTests -only-testing:GymbrosTests/HistoryViewModelTests`

- Implemented Sprint S05p — Phase 1 Polish, with user-requested scope expansion:
  - Added local-only ActivityKit Live Activity/Dynamic Island support via new `GymbrosWidgets` extension, app `Info.plist`, widget `Info.plist`, and `NSSupportsLiveActivities`.
  - Added `RestTimerLiveActivityController`, `RestTimerNotificationScheduler`, `RestTimerDeepLink`, `DeepLinkCoordinator`, and `AppDelegate` notification handling.
  - Rest timer start now schedules local notification + Live Activity; stop/skip/finish cancels timer surfaces.
  - Tapping a rest notification or Live Activity deep-links to Today and opens the active workout exercise page when `programExerciseId` is available.
  - Added `LastSessionReference` / `LastSessionLookupService`; `WorkoutSessionViewModel` loads history references on start/restore and exposes them to `WorkoutExercisePageView`.
  - Added last-session row in the logger, with same-program preference, same-exercise fallback, no-history state, kg/lb formatting, and Thai/English copy.
  - Added shared `.dismissKeyboardOnTap()` and interactive scroll keyboard dismissal to workout and program form surfaces.
  - Added workout set table header (`Set`, kg/lb, `Reps`, `RPE`, `Done`) above active set rows.
  - Added rest timer completion pulse in `RestTimerRingView`, skipped when iOS Reduce Motion is enabled.
  - Added History session duration editing: user edits total minutes; app preserves `startedAt` and updates `endedAt`.
  - Added `WorkoutRepository.updateSessionEndedAt(sessionId:endedAt:)`.
  - Added focused tests: last-session lookup, rest notification scheduling, deep-link parsing, workout ViewModel timer/reference behavior, and History duration editing.
  - Verified:
    `plutil -lint Gymbros/Info.plist`
    `plutil -lint GymbrosWidgets/Info.plist`
    `jq empty Gymbros/Resources/Localizable.xcstrings`
    `jq empty GymbrosWidgets/Localizable.xcstrings`
    `git diff --check`
    `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`
    Focused S05p `xcodebuild test ... -only-testing:...`
    Full suite `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'`
  - Note: `Gymbros.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` is present after follow-up verification.

- Fixed Sprint 5 Settings review follow-ups and app-wide weight-unit behavior:
  - Follow-up logout fix: `AuthService` now listens to Supabase `authStateChanges`, updates `currentUser` from the emitted session, and calls local Supabase sign-out from the Settings button. `RootView` passes its owned auth instance into `SettingsViewModel`, so the signed-out auth event redirects to `SignInView`.
  - Added shared `AppPreferences` and `WeightUnit` formatting/conversion helpers.
  - RootView now refreshes profile preferences after auth/session changes and injects preferences through SwiftUI environment.
  - Settings weight-unit changes persist through `ProfileRepository.updateProfile`, update shared app preferences immediately, roll back on failure, and do not show alerts for `.cancelled`.
  - Sign Out calls `AuthService.signOut()`, resets local preferences, disables while signing out, and avoids `.cancelled` alerts.
  - Workout target chips, active workout set rows, history set rows/editing, and program target-weight editing now display the selected kg/lb unit. User-entered lb values are converted back to kg before repository writes.
  - Bumped `ActiveSessionSnapshot.currentVersion` 3→4 because active-session row text is now stored in the selected display unit.
  - Fixed Settings weight-unit accessibility value and localized `settings.empty.title`.
  - Verified build passes after the auth-listener logout change:
    `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`
  - Verified focused tests pass:
    `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/SettingsViewModelTests -only-testing:GymbrosTests/EnumsTests -only-testing:GymbrosTests/WorkoutSessionViewModelTests`
  - Verified focused Settings tests pass after the auth-listener logout change:
    `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/SettingsViewModelTests`
  - Full-suite escalation was blocked by the approval system usage limit; rerun full suite when approvals are available.
  - Local checks passed: `jq empty Gymbros/Resources/Localizable.xcstrings`, `git diff --check`.

- Wrote Sprint S05p — Phase 1 Polish spec at `.claude/sprints/S05p-phase1-polish/spec.md`.
  - Covers all three trial-feedback items from GYMTRACK.md §9 Phase 1 backlog:
    rest timer background notifications, keyboard dismissal helper, last-session kg/reps reference in logger.
  - Sprint slots between S05 (Settings) and S06 (Smart Comeback) without renumbering existing sprints.
  - No GYMTRACK.md Sprint Tracking table edit yet — to be done when the sprint is scheduled.

## Earlier session did

- Reviewed Sprint 5 Settings implementation.
  - Verified focused Settings tests pass:
    `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/SettingsViewModelTests`
  - Verified full test suite passes:
    `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'`
  - Review follow-ups: avoid surfacing `.cancelled` as a Settings transient alert, fix the formatted weight-unit accessibility label/value, localize or remove the `settings.empty` state, and add the new Settings source/test files before committing.

- Refreshed spec and plan to align with codebase.
- Implemented Sprint 5 — Settings:
  - Created `ProfileRepositoryProviding` protocol and updated `ProfileRepository` to conform to it.
  - Implemented `@Observable` `SettingsViewModel` with loading, weight unit updating, and Apple Sign Out integration.
  - Implemented `SettingsView` using SwiftUI forms, custom picker for weight units (kg/lb), sign out, and placeholder sheets for Privacy Policy and Delete Account.
  - Added full unit test coverage under `GymbrosTests/SettingsViewModelTests.swift` (covering success/failure loading, weight unit persistence, and signing out), all verified passing.
  - Wired `SettingsView` as the 4th tab (gear icon) in `RootView`'s tab navigation.
  - Populated all localized strings (`settings.*`) for both English and Thai in `Localizable.xcstrings`.
  - Deleted `WorkoutSetSyncState` enum and `syncState` field from `WorkoutSetRowState` and `ActiveSessionSetSnapshot`.
  - Bumped `ActiveSessionSnapshot.currentVersion` 2→3 (invalidates old backups gracefully).
  - `completeSet()` no longer calls `upload()` — sets stay local until Finish.
  - `finishSession()` batch-uploads all `isCompleted` sets, throws on failure (backup preserved for retry), clears backup only after `completeSession()` succeeds.
  - `deleteSet()` no longer calls remote `workoutRepository.deleteSet()` (no sets in DB during active session).
  - Removed `syncIndicator`, `onRetry` from `SetRowView`; removed `onRetryUpload` from `WorkoutExercisePageView`, `WorkoutSessionView`, `WorkoutSessionScreen`.
  - Session editing: `SessionDetailViewModel.updateSet()` updates a set in Supabase and patches local state in-place.
  - `EditSetSheet` in `SessionDetailView` — tap any set row to edit weight/reps/RPE.
  - Added `session.set.edit.title` localization key (en/th).
  - Updated tests: deleted `uploadFailureCanBeRetried`, removed syncState assertions from `uploadConflictUpdatesExistingSetAndAllowsFinish`, rewrote `finishSessionSkipsInvalidReuploadForCompletedSets` → `finishSessionSkipsInvalidSets`, added `completeSetDoesNotUpload`, `finishSessionUploadsAllCompletedSets`.
  - All 20 `WorkoutSessionViewModelTests` + 2 `ActiveSessionBackupTests` pass. Full suite passes.

## Earlier session did — fixed Sprint 4 wire-up regressions:

- Fixed Sprint 4 wire-up regressions from review:
  - Restored concrete `@Observable` `TodayViewModel`, `HistoryViewModel`, and `SessionDetailViewModel` implementations.
  - Removed stale debug preview repository conformances that used old `ProgramRepositoryProviding` method names.
  - Kept Today/History/Session Detail views wired to real ViewModels for runtime.
  - Deleted the old UI-only display/mock data files from runtime wiring.
  - Previews now use simple preloaded ViewModel states with `loadsOnAppear: false` instead of mock repositories.
  - Verified targeted tests: `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/TodayViewModelTests -only-testing:GymbrosTests/HistoryViewModelTests`.
  - Verified full suite: `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'`.
- Fixed workout finish-session API error:
  - Changed `WorkoutRepository.completeSession` to send a typed `WorkoutSessionCompletionPayload` containing only `ended_at`.
  - Set the Supabase update to `returning: .minimal` so finishing does not depend on a returned representation.
  - Added `WorkoutRepositoryPayloadTests` coverage for the completion payload.
  - Verified focused tests: `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/WorkoutRepositoryPayloadTests -only-testing:GymbrosTests/WorkoutSessionViewModelTests`.
  - Verified full suite: `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'`.

## Earlier session did

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

- Fixed two S03 workout-session regressions (rest timer background, restore sheet path).
- Task 0 (Spec Lock) for Sprint 4: 8 ambiguities locked in `spec.md` §2.2.

---

## Next up

**Local-first sessions, S06, and Sprint 6.1 (4 of 5 features) are all implemented and committed.** Two manual smoke tests remain — note that Sprint 6.1's `HowDidThatFeelPicker` removal means step 4 of the S06 checklist below (the sheet appearing) **no longer applies**; per-set Easy/Just right/Hard input now replaces it in every mode, and the ramp decision should be verified from those per-set picks directly.

**S06 manual smoke test** (requires editing a `workout_sessions.ended_at` in Supabase to be ≥14 days ago for the active user):
1. Today screen shows `ComebackCardView` with bilingual greeting and reason line (e.g. "ขาดไป 15 วัน / 15 days since last session").
2. Starting a workout from the comeback card uses adjusted weights (×0.9 for 14–20 day gap) and −1 set.
3. Within workout, the "Easing Back" badge appears above the set list on exercises where baseline data is available.
4. ~~Finishing the last set of an exercise shows the `HowDidThatFeelPicker` sheet~~ — **removed by Sprint 6.1**; instead, confirm per-set Easy/Just right/Hard picks drive the next comeback ramp decision directly (no separate end-of-exercise sheet, no clobbering).
5. After reaching baseline weight × reps, a double haptic fires and does not repeat in the same session.
6. Overload hint ("Try X kg next time") appears on exercises in normal mode when ≥2 sessions in last 60 days with RPE ≤7.0.

**Sprint 6.1 manual smoke test** (run in one sitting so the four features are confirmed to coexist — see `.claude/sprints/S06.1-post-launch-feature-wave/plan.md` Task 18 for the full per-feature breakdown):
1. RPE: log a set with each of Easy/Just right/Hard/Clear in a normal session and in History's edit-set form; confirm no raw numbers anywhere.
2. Skip a Day: on a 2+ day program, confirm "Change day" lists every day but the recommended one; pick one, Start, confirm it opens that day; finish it; confirm the *next* recommendation follows the day actually completed (requires a manual pull-to-refresh on Today — it does not auto-refresh after returning from a finished workout, a pre-existing app behavior, not a Sprint 6.1 regression).
3. Training Phase: change it in Settings, relaunch, confirm it persisted.
4. Progressive Overload Advisor: log the same weight for an exercise across 4 sessions at RPE ≤8.0; confirm the card appears on Today (normal mode only, never with the comeback card); set training phase to "Losing weight," confirm it disappears; "Not now" hides it for 14 days; "Try it next time" bumps the program exercise's target weight by 2.5kg and clears the card.
5. Run in both Thai and English device locales; verify all new copy from all four features.

After both smoke tests pass, update `.claude/GYMTRACK.md` §9 Sprint Tracking rows 6 and 6.1 to `✅`, mark this section done here, and either pursue Substitute's approval (Sprint 6.1's 5th, unapproved item) or start **Sprint 7 — Onboarding + Templates + i18n + Brain Polish** (no spec written yet; see `.claude/GYMTRACK.md` §9).

---

## Open follow-ups

- [x] Sprint 5 review: filter `.cancelled` in `SettingsViewModel.updateWeightUnit(_:)` and `signOut()` so user-cancelled operations do not show alerts.
- [x] Sprint 5 review: fix Settings weight-unit accessibility so VoiceOver gets the current unit instead of a raw `%@` placeholder.
- [x] Sprint 5 review: localize or remove `settings.empty`, which is currently extract-only in `Localizable.xcstrings`.
- [x] Sprint 5 review: rerun the full xcodebuild test suite when approval usage is available.
- [ ] Sprint 5 review: add the untracked Settings/Core source/test files before committing; leave local `.antigravitycli/` and `.codex/config.toml` out unless intentionally needed.
- [ ] Light/dark visual sweep of `WorkoutSessionView`, `WorkoutExercisePageView`, `SetRowView`, `RestTimerRingView`, `ProgramExerciseEditorView`, and `GymbrosWidgets` Live Activity in Xcode before broad TestFlight.
- [x] Decided Phase 1 trial-feedback polish → Sprint S05p (spec written at `.claude/sprints/S05p-phase1-polish/spec.md`).
- [ ] Add/update S05p in GYMTRACK.md §9 Sprint Tracking table.
- [ ] After S05p manual smoke passes, update GYMTRACK.md §9 Phase 1 Trial Feedback Polish Backlog items from ☐ to ✓.
- [x] Confirm `Gymbros.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` is present after follow-up verification.
- [ ] `CLAUDE.md` still says the available simulator is `iPhone 17e`; this machine only has `iPhone 17` / `iPhone 17 Pro` / `iPhone 17 Pro Max`. Confirm which is correct going forward (may be a per-machine difference) and update `CLAUDE.md` if `iPhone 17e` is genuinely gone.
- [ ] Sprint 6.1: pursue Substitute's approval (outline discussed 2026-07-23, not yet confirmed) or explicitly defer it past this sprint.
- [ ] Sprint 6.1 final-review Minor findings, deferred (none block shipping): (a) `OverloadAdvisorCardView` shows the recommended day's stalled exercise even after "Change day" swaps to a different day — data isn't wrong, but placement can read as belonging to the wrong day; (b) [fixed 2026-07-24 — `today.overload_advisor.body` no longer hardcodes a session count after the StallDetector window redesign] `today.overload_advisor.body` still uses non-positional `%@` (fine today since en/th share word order, latent hazard for future translations); (c) the 30-session fetch cap on normal days can still under-fire on very high-frequency (4+ day/week) program rotations near the 35-day window's edge, and `fetchSets` calls in `fetchBudgetedSets` run sequentially rather than concurrently — worth revisiting if Today-load latency or advisor recall on such splits becomes a real issue.

---

## How to resume

1. Read this file.
2. Read `.claude/sprints/S06.1-post-launch-feature-wave/plan.md` Task 18 for the full manual smoke breakdown, and run both the S06 and Sprint 6.1 smoke checklists above.
3. Confirm `Package.resolved` remains present before commit.
4. Decide on Substitute (Sprint 6.1's unapproved 5th item) or move to Sprint 7.
5. Update GYMTRACK.md and this file before ending the next session.
