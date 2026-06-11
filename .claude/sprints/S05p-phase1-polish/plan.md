# Sprint S05p — Phase 1 Polish Implementation Plan

## CURRENT STATUS

| Field | Value |
|---|---|
| Status | Workout-session Live Activity + Liquid Glass persistent in-app resume widget follow-ups implemented; manual smoke, full tests, and final build passed |
| Last commit | `51140ea` |
| Known deviations | Scope expanded per user request: local-only ActivityKit Live Activity/Dynamic Island, notification/Live Activity deep link to active exercise, History duration editing, workout set table header, whole-workout Live Activity follow-up, and persistent in-app active-workout resume widget. No APNs ActivityKit push. Notification permission is now requested whenever rest starts, not only when the app is already backgrounded, so a foreground-start/background-during-rest flow can notify. Timer completion now switches to Ready/Go copy instead of continuing count-up UI. Last-session references now preserve per-set weights so mixed-load history can render set-by-set details. |
| Next step | Commit S05p, then move to Sprint 6 planning. |

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
- [x] Follow-up: Live Activity starts for the whole workout, shows elapsed workout time, active set/reps, rest countdown, and ready-for-next-set icon/copy.
- [x] Follow-up: rest-complete notification sound remains the default iOS notification sound in foreground/background notification presentation.
- [x] Follow-up: Lock Screen Live Activity shows three stable lines: workout status, workout name, and weight/set/reps.
- [x] Follow-up: leaving the workout through app navigation now saves the backup, keeps Live Activity/Dynamic Island running, and shows a persistent in-app bottom resume widget across tabs with status, workout name, and exercise/weight/set/reps.
- [x] Follow-up: persistent in-app resume widget now matches the Hevy-style compact two-line pill, floats above the bottom tab/navigation bar, uses only SwiftUI system materials/colors/SF Symbols, and exposes left resume + right stop controls.
- [x] Follow-up: widget stop action shows a localized confirmation, hides the in-app widget, cancels rest notifications, ends Live Activity/Dynamic Island, and preserves the active-session backup for later resume.
- [x] Follow-up: compact pill now uses SwiftUI Liquid Glass on iOS 26 with a material fallback, removes explicit shadow, and uses a visual overlay offset above the tab bar so tab items remain visible and pressable without a transparent hit-test strip.

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
- [x] Follow-up whole-workout Live Activity checks:
  `plutil -lint Gymbros/Info.plist`
  `plutil -lint GymbrosWidgets/Info.plist`
  `jq empty Gymbros/Resources/Localizable.xcstrings`
  `jq empty GymbrosWidgets/Localizable.xcstrings`
  `git diff --check`
  `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/RestTimerNotificationSchedulerTests -only-testing:GymbrosTests/WorkoutSessionViewModelTests`
  `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'`
  `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`
- [x] Follow-up three-line Live Activity + persistent resume widget checks:
  `jq empty Gymbros/Resources/Localizable.xcstrings`
  `jq empty GymbrosWidgets/Localizable.xcstrings`
  `git diff --check`
  `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/WorkoutSessionViewModelTests -only-testing:GymbrosTests/RestTimerNotificationSchedulerTests`
  `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`
- [x] Follow-up persistent bottom widget checks:
  `jq empty Gymbros/Resources/Localizable.xcstrings`
  `jq empty GymbrosWidgets/Localizable.xcstrings`
  `git diff --check`
  `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/WorkoutSessionViewModelTests -only-testing:GymbrosTests/ActiveSessionBackupTests`
  `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`
- [x] Follow-up compact floating pill + stop confirmation checks:
  `jq empty Gymbros/Resources/Localizable.xcstrings`
  `git diff --check`
  `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/ActiveSessionBackupTests -only-testing:GymbrosTests/WorkoutSessionViewModelTests`
  `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`
- [x] Follow-up Liquid Glass above-tab-bar widget checks:
  `jq empty Gymbros/Resources/Localizable.xcstrings`
  `git diff --check`
  `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`
- [x] Final post-manual-smoke checks:
  `jq empty Gymbros/Resources/Localizable.xcstrings`
  `jq empty GymbrosWidgets/Localizable.xcstrings`
  `plutil -lint Gymbros/Info.plist`
  `plutil -lint GymbrosWidgets/Info.plist`
  `git diff --check`
  `xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'`
  `xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build`

## Manual Smoke Test

- [x] Start a workout, complete a set, and verify rest timer appears on Lock Screen/Dynamic Island on a supported device/simulator.
- [x] Tap the Dynamic Island/Live Activity and verify GymBros opens to the active exercise page.
- [x] Re-test after follow-up: background the app during rest and verify local notification fires with Thai/English copy; tap it and verify it opens the active exercise page.
- [x] Stop/skip rest and finish workout; verify Live Activity and pending notification are gone.
- [x] Re-test after follow-up: verify last-session row for same-program history, fallback history, no-history states, and mixed-load sets like `59 × 10 -> 65 × 8 -> 65 × 5`, with no repeated weight unit in the row text.
- [x] Re-test after follow-up: verify workout set table headers align responsively with row values for Set, kg/lb, Reps, RPE, and Done in active and finished states on iPhone and iPad widths.
- [x] Re-test after follow-up: verify tap-outside and scroll keyboard dismissal across workout rows, ProgramExerciseEditorView, and other text-field surfaces.
- [x] Re-test after follow-up: edit workout duration to 60 minutes in History and verify detail/list duration after refresh shows 60 minutes.
- [x] Re-test after follow-up: let rest timer reach zero and verify in-app, Lock Screen, Dynamic Island, and notification show Ready/Go messaging instead of continuing a count-up timer.
- [x] Re-test after whole-workout follow-up: verify Live Activity appears on workout start/restore, shows elapsed workout time outside rest, switches to countdown during rest, and switches to ready/work icon after rest completes.
- [x] Re-test after persistent widget follow-up: leave the workout screen, switch among Today/Programs/History/Settings, verify the compact two-line bottom widget stays visible with status/time and exercise name, then tap left/center to resume the active workout exercise page.
- [x] Re-test after floating widget follow-up: verify the persistent Liquid Glass widget floats above the bottom tab/navigation bar without covering tab labels/buttons or screen content on compact and large iPhone sizes; tap red trash, cancel once, then confirm and verify widget hides while backup remains resumable.
