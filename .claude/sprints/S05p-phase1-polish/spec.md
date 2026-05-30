# Sprint 5p — Phase 1 Polish

> Detailed implementation spec for coding agents.
> Reference: `.claude/GYMTRACK.md` §9 — Phase 1 Trial Feedback Polish Backlog

---

## Overview

**Goal:** Close three trial-feedback polish items so the logger and program forms feel right on real hands and the rest timer is reliable when the user leaves the app.

**Primary acceptance test:** Start a workout → log a set → rest timer rings AND fires a local notification if the app is backgrounded (test by switching to Notes mid-rest); tapping outside a weight/reps field dismisses the keyboard with no value loss; each exercise page shows a "Last: 60 kg × 8, 8, 7" reference line that respects the user's weight unit and shows a non-shaming empty state when there is no history.

**Effort estimate:** Medium (three small features, each touching the workout-session view layer plus one new local-notification helper service).

**Dependencies:** Sprints S01–S05 complete. Reuses `WorkoutRepository.fetchHistory` / `fetchSets`, `RestTimerRingView`, the existing `WorkoutSessionViewModel`, and the `AppError` / `ViewState` pipeline.

---

## 1. Requirements

### Must Have

```text
☐ Rest timer — foreground completion
    Haptic feedback (existing) + 2-cycle ring pulse animation on timer end.
    Pulse gated on UIAccessibility.isReduceMotionEnabled.

☐ Rest timer — background completion
    Schedule a UNNotificationRequest when the rest timer starts.
    Cancel and reschedule when the timer is stopped or restarted.
    Fire default notification sound + localized title/body.
    Cancel all pending rest notifications when the session finishes.

☐ Rest timer — notification permission
    Request [.alert, .sound] contextually: the first time a rest timer fires
    while the app is NOT in the foreground (.active state).
    Persist "have asked" flag in UserDefaults.
    If denied, fall back to foreground-only behavior silently (no error UI).
    Do NOT request permission at first launch or at sign-in.

☐ Keyboard dismissal
    Tapping outside any text field in WorkoutExercisePageView / SetRowView
    and ProgramExerciseEditorView dismisses the keyboard.
    Scrolling a scrollable form dismisses the keyboard interactively.
    No draft weight/reps values are lost when the keyboard is dismissed.
    Implemented as a shared View extension, not duplicated per screen.

☐ Last-session reference in logger
    Each WorkoutExercisePageView shows a compact reference row above the set list.
    Format: "Last: 60 kg × 8, 8, 7"  (or per-set compact hints as fallback).
    Prefer history for the same programExerciseId; fall back to same exerciseId
    across any program.
    Respect the user's WeightUnit setting.
    No history → muted "No previous data" line (not hidden completely).
    isFallback = true → add muted "From a different program" hint.
    Errors loading reference are logged but never block the logger.
    In comeback mode (Sprint 6 seam): label field is a LastSessionReference.Label
    enum; only .last is wired this sprint; .baseline is reserved for Sprint 6.
```

### Out of Scope

```text
✗ watchOS / Live Activity rest-timer surfaces (Sprint 13)
✗ Notification preferences toggle in Settings (Sprint 7+ smart notifications)
✗ Cross-session progression suggestions (Sprint 6 Smart Comeback)
✗ Editing past sets from inside the logger (History edit sheet, Sprint 4/5)
✗ Brand-color or accent changes (whole-app system-color policy unchanged)
✗ Formal superset grouping (open decision, post-Sprint 3)
```

---

## 2. Existing Foundation To Reuse

```text
Gymbros/Presentation/Workout/RestTimerRingView.swift          rest timer UI + haptic
Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift    rest timer state + active session
Gymbros/Presentation/Workout/WorkoutExercisePageView.swift    per-exercise page (add reference row)
Gymbros/Presentation/Workout/WorkoutSessionView.swift         paged container
Gymbros/Presentation/Workout/SetRowView.swift                 weight/reps/RPE inputs
Gymbros/Presentation/Programs/ProgramExerciseEditorView.swift program form inputs
Gymbros/Data/Repository/WorkoutRepository.swift               fetchHistory(limit:) + fetchSets(sessionId:)
Gymbros/Model/Profile.swift                                   weightUnit: WeightUnit
Gymbros/Model/Enums/WeightUnit.swift                          .kg / .lb
Gymbros/Core/ErrorHandling/AppError.swift
Gymbros/Core/ErrorHandling/ViewState.swift
Gymbros/Core/ErrorHandling/ErrorMapper.swift
Gymbros/Core/Extensions/                                      home for the keyboard helper
Gymbros/Resources/Localizable.xcstrings
```

---

## 2.1 Spec Lock Decisions

Task 0 locks these before parallel work starts:

1. **Notification permission scope:** Request `[.alert, .sound]` only (no badge). Triggered from `WorkoutSessionViewModel` when a rest timer fires and `UIApplication.shared.applicationState != .active`. Persisted in `UserDefaults` under key `"rest_timer_notification_asked"`. If denied, foreground-only with no retry prompt this sprint.

2. **Notification identifier scheme:** One identifier per session: `"rest-timer-<sessionId>"`. Starting/restarting a timer cancels the existing identifier via `UNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers:)` before scheduling a new one. `cancelAll()` removes all identifiers with prefix `"rest-timer-"`.

3. **Foreground ring pulse:** Add a `@State var isComplete: Bool` binding into `RestTimerRingView` (or use the existing completion callback). On completion, trigger a `withAnimation(.spring(response: 0.25, dampingFraction: 0.5))` scale 1.0 → 1.08 → 1.0 repeated twice via a `repeatCount(2)` animation, gated on `!UIAccessibility.isReduceMotionEnabled`.

4. **Keyboard helper API:**
   ```swift
   // Gymbros/Core/Extensions/View+DismissKeyboard.swift
   extension View {
       func dismissKeyboardOnTap() -> some View
   }
   ```
   Implementation: `.simultaneousGesture(TapGesture().onEnded { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) })`. Parent `ScrollView` / `Form` also sets `.scrollDismissesKeyboard(.interactively)`.

5. **Last-session reference data shape:**
   ```swift
   struct LastSessionReference {
       enum Label { case last, baseline }   // .baseline reserved for Sprint 6
       var label: Label                      // .last always this sprint
       var weight: Double?                   // nil for bodyweight exercises
       var reps: [Int]                       // per-set reps, e.g. [8, 8, 7]
       var unit: WeightUnit
       var isFallback: Bool                  // true = different program
   }
   ```

6. **Reference fetch strategy:** A new pure-Swift `LastSessionLookupService` in `Data/Services/`. It takes `[WorkoutSession]` + a set dictionary `[UUID: [WorkoutSet]]` already loaded in memory, returns `LastSessionReference?` per exercise. `WorkoutSessionViewModel` calls `WorkoutRepository.fetchHistory(limit: 10)` and `fetchSets(sessionId:)` for each session once on session start (or lazily on first page view), storing results in `lastSessionReferences: [UUID: LastSessionReference?]` keyed by `programExerciseId`. No extra Supabase call is made per exercise page.

7. **Comeback seam:** `LastSessionReference.Label` enum is declared now. Wiring `.baseline` label and the "Baseline: …" copy is deferred to Sprint 6. The reference row rendering in `WorkoutExercisePageView` switches on `label` — Sprint 6 fills the `.baseline` branch.

---

## 3. Product Flow

```text
App launch → authenticated → RootView → TabView

Workout session:
  WorkoutSessionViewModel.loadSession()
    → fetchHistory(limit: 10) + fetchSets(sessionId:) for each
    → builds lastSessionReferences dictionary

  WorkoutExercisePageView (per exercise):
    • Reference row: "Last: 60 kg × 8, 8, 7"  (or empty hint)
    • Input fields + SetRowView (keyboard dismissable)

  User taps outside a field
    → dismissKeyboardOnTap() fires resignFirstResponder
    → keyboard closes, draft weight/reps retained

  User completes a set → rest timer starts
    → RestTimerNotificationScheduler.schedule(after:sessionId:) called
    → Foreground: timer completion → haptic + ring pulse
    → Background: UNNotification fires with localized copy

  User cancels / adjusts rest
    → RestTimerNotificationScheduler.cancel(sessionId:)

  Finish workout
    → RestTimerNotificationScheduler.cancelAll()
    → session complete

Program editor:
  ProgramExerciseEditorView
    → .dismissKeyboardOnTap() applied at root
    → .scrollDismissesKeyboard(.interactively) on Form
```

---

## 4. New Services

### 4.1 RestTimerNotificationScheduler

```swift
// Gymbros/Data/Services/RestTimerNotificationScheduler.swift
@MainActor
final class RestTimerNotificationScheduler {
    private let center = UNUserNotificationCenter.current()
    private let askedKey = "rest_timer_notification_asked"

    func requestAuthorizationIfNeeded() async
    func schedule(after seconds: TimeInterval, sessionId: UUID) async
    func cancel(sessionId: UUID)
    func cancelAll()
}
```

- `requestAuthorizationIfNeeded()`: checks `UserDefaults.standard.bool(forKey: askedKey)`; if not asked, calls `center.requestAuthorization(options: [.alert, .sound])`, sets the flag regardless of result.
- `schedule(after:sessionId:)`: cancels any existing `"rest-timer-<sessionId>"` request, then schedules a `UNTimeIntervalNotificationTrigger` with the given duration.
- `cancel(sessionId:)`: removes pending `"rest-timer-<sessionId>"` request.
- `cancelAll()`: removes all pending requests whose identifier has prefix `"rest-timer-"`.

`WorkoutSessionViewModel` holds `let restTimerScheduler: RestTimerNotificationScheduler` as an injected dependency (defaulted to `RestTimerNotificationScheduler()`).

### 4.2 LastSessionLookupService

```swift
// Gymbros/Data/Services/LastSessionLookupService.swift
struct LastSessionLookupService {
    func reference(
        for programExerciseId: UUID,
        exerciseId: UUID,
        in sessions: [WorkoutSession],       // sorted newest-first, already fetched
        sets: [UUID: [WorkoutSet]],          // sessionId → sets
        unit: WeightUnit
    ) -> LastSessionReference?
}
```

Algorithm:
1. Find the most recent completed session that contains a set with `programExerciseId` matching. If found → `isFallback = false`.
2. If not found, find the most recent completed session with any set whose `exerciseId` matches. If found → `isFallback = true`.
3. From the found session's sets for this exercise, collect `reps` in set-number order. Collect `weight` from set 1 (nil if 0 / bodyweight). Convert to `unit`.
4. Return `nil` if no session found.

---

## 5. WorkoutSessionViewModel Changes

Add to the existing `WorkoutSessionViewModel`:

```text
var lastSessionReferences: [UUID: LastSessionReference?] = [:]  // keyed by programExerciseId
let restTimerScheduler: RestTimerNotificationScheduler

// On session load (loadSession / restoreSession):
//   fetchHistory(limit: 10) + fetchSets for each → build lastSessionReferences

// On rest timer start:
//   restTimerScheduler.schedule(after: restDuration, sessionId: session.id)
//   If app not foregrounded → restTimerScheduler.requestAuthorizationIfNeeded()

// On rest timer cancel/stop:
//   restTimerScheduler.cancel(sessionId: session.id)

// On finishSession:
//   restTimerScheduler.cancelAll()
```

Only `loadSession` / `restoreSession` perform network calls. The reference dictionary is built synchronously from the already-loaded data via `LastSessionLookupService`.

---

## 6. UI Requirements

### 6.1 WorkoutExercisePageView — Reference Row

Add a compact row directly above the set list. Use `.secondary` foreground color, `.caption` or `.footnote` font, monospaced digits (`monospacedDigit()`), single line with `.lineLimit(1).truncationMode(.tail)`.

States:
- `nil` reference → `Text("workout.last_session.empty")` in `.tertiary` foreground.
- `.last` reference, `isFallback = false` → `"Last: 60 kg × 8, 8, 7"`.
- `.last` reference, `isFallback = true` → `"Last: 60 kg × 8, 8, 7 · From a different program"` (or two-line small text).
- Bodyweight (weight == nil) → `"Last: 8, 8, 7 reps"`.
- Sprint 6 seam: `.baseline` branch renders `"Baseline: …"`.

### 6.2 RestTimerRingView — Completion Pulse

When the timer reaches 0:
```swift
// gated: if !UIAccessibility.isReduceMotionEnabled
withAnimation(.spring(response: 0.25, dampingFraction: 0.5).repeatCount(2, autoreverses: true)) {
    scale = 1.08
}
// after animation completes:
scale = 1.0
```

Apply `scaleEffect(scale)` to the ring view's root. Default `scale = 1.0`.

### 6.3 Keyboard Dismissal — Affected Views

Apply at the outermost view root (before `NavigationStack` or immediately inside it):

| View | Change |
|---|---|
| `WorkoutExercisePageView` | `.dismissKeyboardOnTap()` on page root + `.scrollDismissesKeyboard(.interactively)` on the scroll container |
| `SetRowView` | `.dismissKeyboardOnTap()` on row root (belt-and-suspenders for the input row) |
| `ProgramExerciseEditorView` | `.dismissKeyboardOnTap()` on view root + `.scrollDismissesKeyboard(.interactively)` on the `Form` |

Existing `TextField` bindings are unchanged — values are not lost because keyboard dismissal does not reset binding state.

---

## 7. Localization

Add complete Thai and English copy for these key families:

```text
workout.rest_timer.notification.title
  en: "Rest's up"
  th: "พักครบแล้ว"

workout.rest_timer.notification.body
  en: "Time for your next set."
  th: "ถึงเวลาเซ็ตต่อไป"

workout.last_session.reference
  en: "Last: %1$@ × %2$@"    (%1$@ = weight string, %2$@ = reps list "8, 8, 7")
  th: "ครั้งก่อน: %1$@ × %2$@"

workout.last_session.reference.bodyweight
  en: "Last: %@ reps"
  th: "ครั้งก่อน: %@ ครั้ง"

workout.last_session.empty
  en: "No previous data"
  th: "ยังไม่มีข้อมูลก่อนหน้า"

workout.last_session.fallback_hint
  en: "From a different program"
  th: "จากโปรแกรมก่อนหน้า"

accessibility.workout.last_session
  en: "Last session: %@"
  th: "เซสชั่นล่าสุด: %@"
```

Final wording is confirmed at Task 0 of the implementation plan; keys and intent are locked here.

---

## 8. Testing And Acceptance

### Automated tests

**RestTimerNotificationSchedulerTests:**
- `schedule(after:sessionId:)` cancels the previous pending request for the same session.
- `cancelAll()` clears all pending `"rest-timer-*"` requests.
- `requestAuthorizationIfNeeded()` sets the `UserDefaults` flag after the first call.
- If authorization already asked, subsequent calls to `requestAuthorizationIfNeeded()` are no-ops (no double-prompt).

**LastSessionLookupServiceTests:**
- Returns the most recent set data when `programExerciseId` matches.
- Falls back to `exerciseId` match when no `programExerciseId` match exists; `isFallback == true`.
- Returns `nil` when no history exists.
- Respects unit conversion (kg ↔ lb).
- Ignores sets from incomplete sessions.
- Ignores sets with zero weight as bodyweight signal (weight → nil).

**WorkoutSessionViewModelTests (additions):**
- `lastSessionReferences` is populated after `loadSession()` using mock history.
- `finishSession()` calls `scheduler.cancelAll()` (inject mock scheduler).
- Rest timer start with app backgrounded calls `requestAuthorizationIfNeeded()`.

Keyboard helper has no testable logic; covered by manual smoke test.

### Manual smoke test

```text
1. Start a workout with an exercise that has previous sessions.
   → Reference row shows "Last: X kg × n, n, n" with correct unit.

2. Start a workout with a brand-new exercise.
   → Reference row shows "No previous data" (muted, not an error).

3. Tap a weight field, enter a value, tap anywhere outside it.
   → Keyboard dismisses. Value is retained in the field.

4. Open the keyboard then scroll the page.
   → Keyboard dismisses interactively as the scroll begins.

5. Open ProgramExerciseEditorView, tap a field, tap outside.
   → Keyboard dismisses. No value loss.

6. Complete a set. Rest timer starts (Reduce Motion OFF).
   → Timer ring pulses twice on completion.

7. Repeat with Reduce Motion ON (Settings > Accessibility).
   → Timer completes cleanly with no pulse/scale animation.

8. Complete a set, switch to another app (e.g. Notes). Wait for timer.
   → Local notification appears with correct locale copy (Thai or English
     matching device language).

9. Complete a set, switch away, then return before rest ends and stop timer.
   → No notification fires. Verify in Settings > Notifications > GymBros
     (no pending notification listed).

10. Finish the workout.
    → No lingering rest-timer notifications remain pending.

11. Run in Thai locale and English locale; verify all new strings appear correct.
```

### Build and test

```bash
xcodebuild test \
  -project Gymbros.xcodeproj \
  -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e'
```
