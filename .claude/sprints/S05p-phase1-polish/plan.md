# Sprint S05p — Phase 1 Polish Implementation Plan

## CURRENT STATUS

| Field | Value |
|---|---|
| Status | Follow-up fixes implemented and focused tests passed |
| Last commit | `970d8d5` |
| Known deviations | Scope expanded per user request: local-only ActivityKit Live Activity/Dynamic Island, notification/Live Activity deep link to active exercise, History duration editing, and workout set table header. No APNs ActivityKit push. Notification permission is now requested whenever rest starts, not only when the app is already backgrounded, so a foreground-start/background-during-rest flow can notify. Timer completion now switches to Ready/Go copy instead of continuing count-up UI. Last-session references now preserve per-set weights so mixed-load history can render set-by-set details. |
| Next step | Re-run manual smoke for local notification fire/tap-back, global keyboard dismissal, mixed-load last-session row copy, responsive table column alignment on iPhone/iPad, and rest timer Ready state in app/Live Activity/Dynamic Island. |

## Completed Scope

- [x] Added `LastSessionReference` and `LastSessionLookupService`.
- [x] Added rest timer local notification scheduling with contextual authorization flag and deep-link `userInfo`.
- [x] Added local-only ActivityKit Live Activity controller and `GymbrosWidgets` WidgetKit extension for Lock Screen/Dynamic Island.
- [x] Registered `NSSupportsLiveActivities`, `gymbros://` deep-link URL scheme, and embedded the widget extension in the app target.
- [x] Added deep-link routing from Live Activity/notification back to Today -> active `WorkoutSessionScreen`, selecting the active exercise when `programExerciseId` is present.
- [x] Wired `WorkoutSessionViewModel` to build last-session references on start/restore and to start/cancel notification + Live Activity rest timer surfaces.
- [x] Added last-session reference row in `WorkoutExercisePageView`.
- [x] Added workout set table header: set / kg-or-lb / reps / RPE / done.
- [x] Added shared `.dismissKeyboardOnTap()` helper and applied it to workout and program form surfaces with interactive scroll dismissal.
- [x] Added rest timer completion pulse gated by Reduce Motion.
- [x] Added History session duration editing by updating `endedAt` while preserving `startedAt`.
- [x] Added English and Thai localizations for all new app and widget strings.
- [x] Added focused tests for lookup, notification scheduling, deep links, ViewModel timer/reference behavior, and History duration editing.
- [x] Follow-up: rest timer now requests notification authorization at rest start and uses refined ready-for-next-set Thai/English copy.
- [x] Follow-up: notification delegate presents ready notifications even if the app is foregrounded and keeps tap-back routing through the active workout deep link.
- [x] Follow-up: root-level `.dismissKeyboardOnTap()` applies tap-outside keyboard dismissal across the app.
- [x] Follow-up: removed repeated kg/lb labels from active set rows and removed the unit suffix from the last-session reference row.
- [x] Follow-up: History duration display now rounds minutes, preventing a saved 60-minute workout from rendering as 59 minutes.
- [x] Follow-up: workout set table now measures available width and computes responsive columns for iPhone/iPad while keeping headers aligned with row values.
- [x] Follow-up: rest timer completion freezes the in-app timer at zero, shows Ready copy, and marks the Live Activity complete so Lock Screen/Dynamic Island show ready messaging instead of counting upward.
- [x] Follow-up: last-session references keep per-set weight/reps details, so mixed-load sessions render like `59 × 10 -> 65 × 8 -> 65 × 5` instead of flattening under the first weight.

## Verification

- [x] `plutil -lint Gymbros/Info.plist`
- [x] `plutil -lint GymbrosWidgets/Info.plist`
- [x] `jq empty Gymbros/Resources/Localizable.xcstrings`
- [x] `jq empty GymbrosWidgets/Localizable.xcstrings`
- [x] `git diff --check`
- [x] `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`
- [x] Focused S05p tests:
  `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/LastSessionLookupServiceTests -only-testing:GymbrosTests/RestTimerNotificationSchedulerTests -only-testing:GymbrosTests/RestTimerDeepLinkTests -only-testing:GymbrosTests/WorkoutSessionViewModelTests -only-testing:GymbrosTests/HistoryViewModelTests`
- [x] Full suite:
  `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'`
- [x] Follow-up string catalog check:
  `jq empty Gymbros/Resources/Localizable.xcstrings`
- [x] Follow-up focused tests:
  `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/RestTimerNotificationSchedulerTests -only-testing:GymbrosTests/WorkoutSessionViewModelTests -only-testing:GymbrosTests/HistoryViewModelTests`
- [x] Follow-up timer/header focused tests:
  `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/WorkoutSessionViewModelTests -only-testing:GymbrosTests/RestTimerNotificationSchedulerTests`
- [x] Follow-up diff whitespace check:
  `git diff --check`
- [x] Follow-up mixed-load last-session checks:
  `jq empty Gymbros/Resources/Localizable.xcstrings`
  `git diff --check`
  `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/LastSessionLookupServiceTests -only-testing:GymbrosTests/WorkoutSessionViewModelTests`

## Manual Smoke Test

- [x] Start a workout, complete a set, and verify rest timer appears on Lock Screen/Dynamic Island on a supported device/simulator.
- [x] Tap the Dynamic Island/Live Activity and verify GymBros opens to the active exercise page.
- [ ] Re-test after follow-up: background the app during rest and verify local notification fires with Thai/English copy; tap it and verify it opens the active exercise page.
- [x] Stop/skip rest and finish workout; verify Live Activity and pending notification are gone.
- [ ] Re-test after follow-up: verify last-session row for same-program history, fallback history, no-history states, and mixed-load sets like `59 × 10 -> 65 × 8 -> 65 × 5`, with no repeated weight unit in the row text.
- [ ] Re-test after follow-up: verify workout set table headers align responsively with row values for Set, kg/lb, Reps, RPE, and Done in active and finished states on iPhone and iPad widths.
- [ ] Re-test after follow-up: verify tap-outside and scroll keyboard dismissal across workout rows, ProgramExerciseEditorView, and other text-field surfaces.
- [ ] Re-test after follow-up: edit workout duration to 60 minutes in History and verify detail/list duration after refresh shows 60 minutes.
- [ ] Re-test after follow-up: let rest timer reach zero and verify in-app, Lock Screen, Dynamic Island, and notification show Ready/Go messaging instead of continuing a count-up timer.
