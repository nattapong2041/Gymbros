# Sprint S05p — Phase 1 Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three polish features to the workout logger: background rest-timer notifications, tap-to-dismiss-keyboard helpers on workout/program forms, and a "last session" reference row on each exercise page.

**Architecture:** Pure services (`LastSessionLookupService`, `RestTimerNotificationScheduler`) injected into `WorkoutSessionViewModel`; UI changes in `WorkoutExercisePageView`, `RestTimerRingView`, `SetRowView`, `ProgramExerciseEditorView`; a shared `View+DismissKeyboard` extension wires keyboard dismissal. All spec decisions are locked in `spec.md §2.1`.

**Tech Stack:** Swift 5.9, SwiftUI, iOS 17+, `@Observable`, UserNotifications, `@testable import Gymbros`, Swift Testing.

---

## CURRENT STATUS

| Field | Value |
|---|---|
| Status | Ready to implement |
| Last commit | `25ee038` |
| Next step | Task 1 — LastSessionLookupService |

---

## File Map

| Path | Action | Purpose |
|---|---|---|
| `Gymbros/Data/Services/LastSessionLookupService.swift` | **Create** | `LastSessionReference` struct + `LastSessionLookupService` |
| `Gymbros/Data/Services/RestTimerNotificationScheduler.swift` | **Create** | `NotificationCenterProviding` protocol + `RestTimerScheduling` protocol + `RestTimerNotificationScheduler` class |
| `Gymbros/Core/Extensions/View+DismissKeyboard.swift` | **Create** | `.dismissKeyboardOnTap()` view modifier |
| `GymbrosTests/LastSessionLookupServiceTests.swift` | **Create** | Unit tests for the lookup service |
| `GymbrosTests/RestTimerNotificationSchedulerTests.swift` | **Create** | Unit tests with fake notification center |
| `Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift` | **Modify** | Add `restTimerScheduler`, `lastSessionReferences`, `buildLastSessionReferences()` |
| `Gymbros/Presentation/Workout/RestTimerRingView.swift` | **Modify** | Add `@State var scale` + pulse animation on completion |
| `Gymbros/Presentation/Workout/WorkoutExercisePageView.swift` | **Modify** | Add `lastSessionReference` param + reference row + `.dismissKeyboardOnTap()` |
| `Gymbros/Presentation/Workout/SetRowView.swift` | **Modify** | Add `.dismissKeyboardOnTap()` on row root |
| `Gymbros/Presentation/Workout/WorkoutSessionView.swift` | **Modify** | Add `lastSessionReferences` param, thread to `WorkoutExercisePageView` |
| `Gymbros/Presentation/Workout/WorkoutSessionScreen.swift` | **Modify** | Pass `viewModel.lastSessionReferences` to `WorkoutSessionView` |
| `Gymbros/Presentation/Programs/ProgramExerciseEditorView.swift` | **Modify** | Add `.dismissKeyboardOnTap()` + `.scrollDismissesKeyboard(.interactively)` |
| `Gymbros/Resources/Localizable.xcstrings` | **Modify** | Add 7 new localization keys |
| `GymbrosTests/WorkoutSessionViewModelTests.swift` | **Modify** | Add `historyResult` to fake repo + 3 new ViewModel tests |

---

## Task 1: LastSessionReference + LastSessionLookupService (TDD)

**Files:**
- Create: `Gymbros/Data/Services/LastSessionLookupService.swift`
- Create: `GymbrosTests/LastSessionLookupServiceTests.swift`

- [ ] **Step 1.1: Write the test file**

Create `GymbrosTests/LastSessionLookupServiceTests.swift`:

```swift
import Testing
import Foundation
@testable import Gymbros

@Suite("LastSessionLookupService")
struct LastSessionLookupServiceTests {
    private let service = LastSessionLookupService()
    private let programExerciseId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let exerciseId        = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let userId            = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    private func makeSession(id: UUID = UUID(), endedAt: Date? = Date()) -> WorkoutSession {
        WorkoutSession(
            id: id, userId: userId, programDayId: nil,
            startedAt: Date().addingTimeInterval(-3600),
            endedAt: endedAt, notes: nil,
            createdAt: Date().addingTimeInterval(-3600)
        )
    }

    private func makeSet(
        sessionId: UUID,
        programExerciseId: UUID?,
        exerciseId: UUID,
        setNumber: Int,
        weight: Double,
        reps: Int
    ) -> WorkoutSet {
        WorkoutSet(
            id: UUID(), sessionId: sessionId,
            exerciseId: exerciseId,
            programExerciseId: programExerciseId,
            setNumber: setNumber, weight: weight, reps: reps,
            rpe: nil, targetRestSeconds: nil, actualRestSeconds: nil,
            restStartedAt: nil, restEndedAt: nil,
            completedAt: Date(), notes: nil
        )
    }

    @Test func returnsNilWhenNoHistory() {
        let result = service.reference(
            for: programExerciseId, exerciseId: exerciseId,
            in: [], sets: [:], unit: .kg
        )
        #expect(result == nil)
    }

    @Test func returnsReferenceForProgramExerciseIdMatch() {
        let session = makeSession()
        let s1 = makeSet(sessionId: session.id, programExerciseId: programExerciseId, exerciseId: exerciseId, setNumber: 1, weight: 60, reps: 8)
        let s2 = makeSet(sessionId: session.id, programExerciseId: programExerciseId, exerciseId: exerciseId, setNumber: 2, weight: 60, reps: 8)
        let s3 = makeSet(sessionId: session.id, programExerciseId: programExerciseId, exerciseId: exerciseId, setNumber: 3, weight: 60, reps: 7)

        let result = service.reference(
            for: programExerciseId, exerciseId: exerciseId,
            in: [session], sets: [session.id: [s1, s2, s3]], unit: .kg
        )

        #expect(result?.weight == 60)
        #expect(result?.reps == [8, 8, 7])
        #expect(result?.isFallback == false)
        #expect(result?.label == .last)
        #expect(result?.unit == .kg)
    }

    @Test func fallsBackToExerciseIdWhenNoProgramExerciseMatch() {
        let otherPeId = UUID()
        let session = makeSession()
        let s1 = makeSet(sessionId: session.id, programExerciseId: otherPeId, exerciseId: exerciseId, setNumber: 1, weight: 80, reps: 5)

        let result = service.reference(
            for: programExerciseId, exerciseId: exerciseId,
            in: [session], sets: [session.id: [s1]], unit: .kg
        )

        #expect(result?.weight == 80)
        #expect(result?.reps == [5])
        #expect(result?.isFallback == true)
    }

    @Test func ignoresIncompleteSessions() {
        let session = makeSession(endedAt: nil)
        let s1 = makeSet(sessionId: session.id, programExerciseId: programExerciseId, exerciseId: exerciseId, setNumber: 1, weight: 60, reps: 8)

        let result = service.reference(
            for: programExerciseId, exerciseId: exerciseId,
            in: [session], sets: [session.id: [s1]], unit: .kg
        )

        #expect(result == nil)
    }

    @Test func convertsWeightToLb() {
        let session = makeSession()
        let s1 = makeSet(sessionId: session.id, programExerciseId: programExerciseId, exerciseId: exerciseId, setNumber: 1, weight: 60, reps: 8)

        let result = service.reference(
            for: programExerciseId, exerciseId: exerciseId,
            in: [session], sets: [session.id: [s1]], unit: .lb
        )

        #expect(result?.unit == .lb)
        let expectedLbs = 60 * 2.2046226218
        #expect(abs((result?.weight ?? 0) - expectedLbs) < 0.001)
    }

    @Test func treatsZeroWeightAsBodyweight() {
        let session = makeSession()
        let s1 = makeSet(sessionId: session.id, programExerciseId: programExerciseId, exerciseId: exerciseId, setNumber: 1, weight: 0, reps: 10)
        let s2 = makeSet(sessionId: session.id, programExerciseId: programExerciseId, exerciseId: exerciseId, setNumber: 2, weight: 0, reps: 10)

        let result = service.reference(
            for: programExerciseId, exerciseId: exerciseId,
            in: [session], sets: [session.id: [s1, s2]], unit: .kg
        )

        #expect(result?.weight == nil)
        #expect(result?.reps == [10, 10])
    }

    @Test func returnsNilWhenMatchingSessionHasNoSetsForExercise() {
        let session = makeSession()
        let otherExerciseId = UUID()
        let s1 = makeSet(sessionId: session.id, programExerciseId: nil, exerciseId: otherExerciseId, setNumber: 1, weight: 60, reps: 8)

        let result = service.reference(
            for: programExerciseId, exerciseId: exerciseId,
            in: [session], sets: [session.id: [s1]], unit: .kg
        )

        #expect(result == nil)
    }

    @Test func picksNewestSessionWhenMultipleMatch() {
        let older = makeSession(id: UUID(), endedAt: Date().addingTimeInterval(-7200))
        let newer = makeSession(id: UUID(), endedAt: Date().addingTimeInterval(-3600))
        let oldSet = makeSet(sessionId: older.id, programExerciseId: programExerciseId, exerciseId: exerciseId, setNumber: 1, weight: 60, reps: 8)
        let newSet = makeSet(sessionId: newer.id, programExerciseId: programExerciseId, exerciseId: exerciseId, setNumber: 1, weight: 80, reps: 5)

        let result = service.reference(
            for: programExerciseId, exerciseId: exerciseId,
            in: [older, newer],
            sets: [older.id: [oldSet], newer.id: [newSet]],
            unit: .kg
        )

        #expect(result?.weight == 80)
        #expect(result?.reps == [5])
    }
}
```

- [ ] **Step 1.2: Run the tests to see them fail**

```bash
xcodebuild test \
  -project Gymbros.xcodeproj \
  -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:GymbrosTests/LastSessionLookupServiceTests
```

Expected: compile error — `LastSessionLookupService` not found.

- [ ] **Step 1.3: Create the service file**

Create `Gymbros/Data/Services/LastSessionLookupService.swift`:

```swift
import Foundation

struct LastSessionReference {
    enum Label: Equatable { case last, baseline }
    var label: Label
    var weight: Double?     // already converted to `unit`; nil = bodyweight
    var reps: [Int]
    var unit: WeightUnit
    var isFallback: Bool
}

struct LastSessionLookupService {
    func reference(
        for programExerciseId: UUID,
        exerciseId: UUID,
        in sessions: [WorkoutSession],
        sets: [UUID: [WorkoutSet]],
        unit: WeightUnit
    ) -> LastSessionReference? {
        let completed = sessions
            .filter(\.isComplete)
            .sorted { $0.startedAt > $1.startedAt }

        if let result = find(in: completed, sets: sets, matching: { $0.programExerciseId == programExerciseId }, unit: unit, isFallback: false) {
            return result
        }
        return find(in: completed, sets: sets, matching: { $0.exerciseId == exerciseId }, unit: unit, isFallback: true)
    }

    private func find(
        in sessions: [WorkoutSession],
        sets: [UUID: [WorkoutSet]],
        matching predicate: (WorkoutSet) -> Bool,
        unit: WeightUnit,
        isFallback: Bool
    ) -> LastSessionReference? {
        for session in sessions {
            let matching = (sets[session.id] ?? []).filter(predicate).sorted { $0.setNumber < $1.setNumber }
            guard !matching.isEmpty else { continue }
            return makeReference(from: matching, unit: unit, isFallback: isFallback)
        }
        return nil
    }

    private func makeReference(from sets: [WorkoutSet], unit: WeightUnit, isFallback: Bool) -> LastSessionReference {
        let firstWeight = sets[0].weight
        let weight: Double? = firstWeight == 0 ? nil : unit.displayValue(fromKilograms: firstWeight)
        return LastSessionReference(
            label: .last,
            weight: weight,
            reps: sets.map(\.reps),
            unit: unit,
            isFallback: isFallback
        )
    }
}
```

- [ ] **Step 1.4: Run tests again — they should pass**

```bash
xcodebuild test \
  -project Gymbros.xcodeproj \
  -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:GymbrosTests/LastSessionLookupServiceTests
```

Expected: all 8 tests PASS.

- [ ] **Step 1.5: Commit**

```bash
git add Gymbros/Data/Services/LastSessionLookupService.swift \
        GymbrosTests/LastSessionLookupServiceTests.swift
git commit -m "feat(s05p): add LastSessionReference + LastSessionLookupService with tests"
```

---

## Task 2: RestTimerNotificationScheduler (TDD)

**Files:**
- Create: `Gymbros/Data/Services/RestTimerNotificationScheduler.swift`
- Create: `GymbrosTests/RestTimerNotificationSchedulerTests.swift`

- [ ] **Step 2.1: Write the test file**

Create `GymbrosTests/RestTimerNotificationSchedulerTests.swift`:

```swift
import Testing
import Foundation
import UserNotifications
@testable import Gymbros

@MainActor
@Suite("RestTimerNotificationScheduler")
struct RestTimerNotificationSchedulerTests {

    private func makeScheduler() -> (RestTimerNotificationScheduler, FakeNotificationCenter, UserDefaults) {
        let fake = FakeNotificationCenter()
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let scheduler = RestTimerNotificationScheduler(center: fake, userDefaults: defaults)
        return (scheduler, fake, defaults)
    }

    @Test func scheduleAddsARequest() async {
        let (scheduler, fake, _) = makeScheduler()
        let sessionId = UUID()

        await scheduler.schedule(after: 60, sessionId: sessionId)

        #expect(fake.addedRequests.count == 1)
        #expect(fake.addedRequests[0].identifier == "rest-timer-\(sessionId.uuidString)")
    }

    @Test func scheduleReplacesExistingRequestForSameSession() async {
        let (scheduler, fake, _) = makeScheduler()
        let sessionId = UUID()

        await scheduler.schedule(after: 60, sessionId: sessionId)
        await scheduler.schedule(after: 90, sessionId: sessionId)

        let id = "rest-timer-\(sessionId.uuidString)"
        #expect(fake.removedIdentifiers.contains(id))
        #expect(fake.addedRequests.count == 1)
        let trigger = fake.addedRequests[0].trigger as? UNTimeIntervalNotificationTrigger
        #expect(trigger?.timeInterval == 90)
    }

    @Test func cancelRemovesPendingRequest() async {
        let (scheduler, fake, _) = makeScheduler()
        let sessionId = UUID()

        await scheduler.schedule(after: 60, sessionId: sessionId)
        scheduler.cancel(sessionId: sessionId)

        #expect(fake.addedRequests.isEmpty)
    }

    @Test func cancelAllRemovesAllScheduledRequests() async {
        let (scheduler, fake, _) = makeScheduler()
        let id1 = UUID()
        let id2 = UUID()

        await scheduler.schedule(after: 60, sessionId: id1)
        await scheduler.schedule(after: 90, sessionId: id2)
        scheduler.cancelAll()

        #expect(fake.addedRequests.isEmpty)
    }

    @Test func requestAuthorizationSetsUserDefaultsFlag() async {
        let (scheduler, _, defaults) = makeScheduler()

        #expect(defaults.bool(forKey: "rest_timer_notification_asked") == false)

        await scheduler.requestAuthorizationIfNeeded()

        #expect(defaults.bool(forKey: "rest_timer_notification_asked") == true)
    }

    @Test func requestAuthorizationIsNoOpWhenAlreadyAsked() async {
        let (scheduler, fake, defaults) = makeScheduler()
        defaults.set(true, forKey: "rest_timer_notification_asked")

        await scheduler.requestAuthorizationIfNeeded()
        await scheduler.requestAuthorizationIfNeeded()

        #expect(fake.authorizationRequestCount == 0)
    }
}

@MainActor
private final class FakeNotificationCenter: NotificationCenterProviding {
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var authorizationGranted = true
    var authorizationRequestCount = 0

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequestCount += 1
        return authorizationGranted
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        addedRequests.removeAll { identifiers.contains($0.identifier) }
    }
}
```

- [ ] **Step 2.2: Run the tests to see them fail**

```bash
xcodebuild test \
  -project Gymbros.xcodeproj \
  -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:GymbrosTests/RestTimerNotificationSchedulerTests
```

Expected: compile error — `RestTimerNotificationScheduler`, `NotificationCenterProviding` not found.

- [ ] **Step 2.3: Create the scheduler file**

Create `Gymbros/Data/Services/RestTimerNotificationScheduler.swift`:

```swift
import UserNotifications
import Foundation

@MainActor
protocol NotificationCenterProviding: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationCenterProviding {}

@MainActor
protocol RestTimerScheduling: AnyObject {
    func requestAuthorizationIfNeeded() async
    func schedule(after seconds: TimeInterval, sessionId: UUID) async
    func cancel(sessionId: UUID)
    func cancelAll()
}

@MainActor
final class RestTimerNotificationScheduler: RestTimerScheduling {
    private let center: any NotificationCenterProviding
    private let userDefaults: UserDefaults
    private let askedKey = "rest_timer_notification_asked"
    private var scheduledIdentifiers: [String] = []

    init(
        center: (any NotificationCenterProviding)? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.center = center ?? UNUserNotificationCenter.current()
        self.userDefaults = userDefaults
    }

    func requestAuthorizationIfNeeded() async {
        guard !userDefaults.bool(forKey: askedKey) else { return }
        userDefaults.set(true, forKey: askedKey)
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(after seconds: TimeInterval, sessionId: UUID) async {
        let identifier = "rest-timer-\(sessionId.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        scheduledIdentifiers.removeAll { $0 == identifier }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "workout.rest_timer.notification.title")
        content.body = String(localized: "workout.rest_timer.notification.body")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(seconds, 1),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
        scheduledIdentifiers.append(identifier)
    }

    func cancel(sessionId: UUID) {
        let identifier = "rest-timer-\(sessionId.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        scheduledIdentifiers.removeAll { $0 == identifier }
    }

    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: scheduledIdentifiers)
        scheduledIdentifiers.removeAll()
    }
}
```

- [ ] **Step 2.4: Run tests — they should pass**

```bash
xcodebuild test \
  -project Gymbros.xcodeproj \
  -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:GymbrosTests/RestTimerNotificationSchedulerTests
```

Expected: all 6 tests PASS.

- [ ] **Step 2.5: Commit**

```bash
git add Gymbros/Data/Services/RestTimerNotificationScheduler.swift \
        GymbrosTests/RestTimerNotificationSchedulerTests.swift
git commit -m "feat(s05p): add RestTimerNotificationScheduler with notification protocol and tests"
```

---

## Task 3: View+DismissKeyboard helper + apply to views

**Files:**
- Create: `Gymbros/Core/Extensions/View+DismissKeyboard.swift`
- Modify: `Gymbros/Presentation/Workout/WorkoutExercisePageView.swift`
- Modify: `Gymbros/Presentation/Workout/SetRowView.swift`
- Modify: `Gymbros/Presentation/Programs/ProgramExerciseEditorView.swift`

- [ ] **Step 3.1: Create the keyboard helper**

Create `Gymbros/Core/Extensions/View+DismissKeyboard.swift`:

```swift
import SwiftUI
import UIKit

extension View {
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        )
    }
}
```

- [ ] **Step 3.2: Apply to WorkoutExercisePageView**

In `Gymbros/Presentation/Workout/WorkoutExercisePageView.swift`, change the outermost `ScrollView` call to add `.dismissKeyboardOnTap()` and `.scrollDismissesKeyboard(.interactively)`:

```swift
// Before:
var body: some View {
    ScrollView {
        VStack(spacing: 24) {

// After:
var body: some View {
    ScrollView {
        VStack(spacing: 24) {
```

Add the modifiers on the `ScrollView` closing brace — change:
```swift
        .padding(.bottom, 32)
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
```

To:
```swift
        .padding(.bottom, 32)
    }
    .scrollDismissesKeyboard(.interactively)
    .dismissKeyboardOnTap()
    .background(Color(uiColor: .systemGroupedBackground))
}
```

- [ ] **Step 3.3: Apply to SetRowView**

In `Gymbros/Presentation/Workout/SetRowView.swift`, find the closing of the `HStack` that is the `body` root and add `.dismissKeyboardOnTap()` on it. The existing body is:

```swift
var body: some View {
    HStack(spacing: 12) {
        // ...
    }
    // existing modifiers...
}
```

Add after the last existing modifier on the HStack:

```swift
    .dismissKeyboardOnTap()
```

Look for the existing `.contextMenu` or `.swipeActions` — add after whichever is the last modifier on the `HStack`.

- [ ] **Step 3.4: Apply to ProgramExerciseEditorView**

In `Gymbros/Presentation/Programs/ProgramExerciseEditorView.swift`, add `.dismissKeyboardOnTap()` and `.scrollDismissesKeyboard(.interactively)` to the `Form`:

```swift
// Before:
NavigationStack {
    Form {
        // ...
    }
    .navigationTitle(...)

// After:
NavigationStack {
    Form {
        // ...
    }
    .scrollDismissesKeyboard(.interactively)
    .dismissKeyboardOnTap()
    .navigationTitle(...)
```

- [ ] **Step 3.5: Build to verify no errors**

```bash
xcodebuild \
  -project Gymbros.xcodeproj \
  -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3.6: Commit**

```bash
git add Gymbros/Core/Extensions/View+DismissKeyboard.swift \
        Gymbros/Presentation/Workout/WorkoutExercisePageView.swift \
        Gymbros/Presentation/Workout/SetRowView.swift \
        Gymbros/Presentation/Programs/ProgramExerciseEditorView.swift
git commit -m "feat(s05p): add dismissKeyboardOnTap helper and apply to workout + program forms"
```

---

## Task 4: WorkoutSessionViewModel integration + new ViewModel tests

**Files:**
- Modify: `Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift`
- Modify: `GymbrosTests/WorkoutSessionViewModelTests.swift`

- [ ] **Step 4.1: Extend the fake workout repository**

In `GymbrosTests/WorkoutSessionViewModelTests.swift`, find `private final class FakeWorkoutRepository` and add a `historyResult` property + update `fetchHistory`:

```swift
// Add this property to FakeWorkoutRepository:
var historyResult: [WorkoutSession]?

// Change fetchHistory from:
func fetchHistory(limit: Int) async throws -> [WorkoutSession] {
    [session]
}

// To:
func fetchHistory(limit: Int) async throws -> [WorkoutSession] {
    historyResult ?? [session]
}
```

- [ ] **Step 4.2: Add FakeRestTimerScheduler to the test file**

At the bottom of `WorkoutSessionViewModelTests.swift`, before the closing of the file, add:

```swift
@MainActor
private final class FakeRestTimerScheduler: RestTimerScheduling {
    var scheduledCalls: [(seconds: TimeInterval, sessionId: UUID)] = []
    var cancelledSessionIds: [UUID] = []
    var cancelAllCount = 0
    var requestAuthCount = 0

    func requestAuthorizationIfNeeded() async { requestAuthCount += 1 }
    func schedule(after seconds: TimeInterval, sessionId: UUID) async { scheduledCalls.append((seconds, sessionId)) }
    func cancel(sessionId: UUID) { cancelledSessionIds.append(sessionId) }
    func cancelAll() { cancelAllCount += 1 }
}
```

- [ ] **Step 4.3: Update makeViewModel to accept scheduler**

Find `private func makeViewModel(` in `WorkoutSessionViewModelTests.swift` and add `restTimerScheduler` parameter:

```swift
private func makeViewModel(
    workoutRepository: FakeWorkoutRepository? = nil,
    programRepository: FakeWorkoutProgramRepository? = nil,
    weightUnit: WeightUnit = .kg,
    restTimerScheduler: (any RestTimerScheduling)? = nil
) -> WorkoutSessionViewModel {
    WorkoutSessionViewModel(
        workoutRepository: workoutRepository ?? FakeWorkoutRepository(),
        programRepository: programRepository ?? FakeWorkoutProgramRepository(),
        exerciseRepository: FakeWorkoutExerciseRepository(),
        backupRepository: FakeBackupRepository(),
        restTimerScheduler: restTimerScheduler,
        weightUnit: weightUnit
    )
}
```

- [ ] **Step 4.4: Write 3 new ViewModel tests**

Add these tests to the `WorkoutSessionViewModelTests` suite:

```swift
@Test func startPopulatesLastSessionReferencesFromHistory() async throws {
    let workoutRepository = FakeWorkoutRepository()
    let pastSessionId = UUID()
    let pastSession = WorkoutSession(
        id: pastSessionId, userId: ProgramSamples.userId, programDayId: nil,
        startedAt: ProgramSamples.createdAt.addingTimeInterval(-86400),
        endedAt: ProgramSamples.createdAt.addingTimeInterval(-82800),
        notes: nil, createdAt: ProgramSamples.createdAt.addingTimeInterval(-86400)
    )
    workoutRepository.historyResult = [pastSession]
    workoutRepository.sets = [
        WorkoutSet(
            id: UUID(), sessionId: pastSessionId,
            exerciseId: ProgramSamples.benchExerciseId,
            programExerciseId: ProgramSamples.benchProgramExerciseId,
            setNumber: 1, weight: 80, reps: 5,
            rpe: nil, targetRestSeconds: nil, actualRestSeconds: nil,
            restStartedAt: nil, restEndedAt: nil,
            completedAt: ProgramSamples.createdAt.addingTimeInterval(-82800),
            notes: nil
        )
    ]
    let viewModel = makeViewModel(workoutRepository: workoutRepository)

    await viewModel.start(programDayId: ProgramSamples.upperDayId)

    let ref = viewModel.lastSessionReferences[ProgramSamples.benchProgramExerciseId]
    #expect(ref != nil)
    #expect(ref??.weight == 80)
    #expect(ref??.reps == [5])
    #expect(ref??.isFallback == false)
}

@Test func finishSessionCallsCancelAllOnScheduler() async throws {
    let scheduler = FakeRestTimerScheduler()
    let viewModel = makeViewModel(restTimerScheduler: scheduler)

    await viewModel.start(programDayId: ProgramSamples.upperDayId)
    let row = try firstRow(viewModel)
    await viewModel.completeSet(setId: row.id)
    await viewModel.finishExercise(programExerciseId: ProgramSamples.benchProgramExerciseId)
    await viewModel.finishSession()

    #expect(scheduler.cancelAllCount == 1)
}

@Test func startRestTimerSchedulesNotification() async throws {
    let scheduler = FakeRestTimerScheduler()
    let viewModel = makeViewModel(restTimerScheduler: scheduler)

    await viewModel.start(programDayId: ProgramSamples.upperDayId)
    viewModel.startRestTimer(seconds: 90, sourceSetId: UUID())

    // Wait for the async Task inside startRestTimer to complete
    try await Task.sleep(for: .milliseconds(100))
    #expect(scheduler.scheduledCalls.count == 1)
    #expect(scheduler.scheduledCalls[0].seconds == 90)
}
```

- [ ] **Step 4.5: Run existing + new tests to see failures**

```bash
xcodebuild test \
  -project Gymbros.xcodeproj \
  -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:GymbrosTests/WorkoutSessionViewModelTests
```

Expected: compile errors — `restTimerScheduler` param not in `WorkoutSessionViewModel.init`, `lastSessionReferences` not a property.

- [ ] **Step 4.6: Update WorkoutSessionViewModel**

In `Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift`:

**Add two new properties** after `private var weightUnit: WeightUnit`:

```swift
var lastSessionReferences: [UUID: LastSessionReference?] = [:]
private let restTimerScheduler: any RestTimerScheduling
```

**Update `init`** — add `restTimerScheduler` parameter (before `weightUnit`):

```swift
init(
    workoutRepository: WorkoutRepositoryProviding? = nil,
    programRepository: ProgramRepositoryProviding? = nil,
    exerciseRepository: ExerciseRepositoryProviding? = nil,
    backupRepository: ActiveSessionBackupRepositoryProviding? = nil,
    restTimerScheduler: (any RestTimerScheduling)? = nil,
    weightUnit: WeightUnit = .kg,
    now: @escaping () -> Date = Date.init
) {
    self.workoutRepository = workoutRepository ?? WorkoutRepository()
    self.programRepository = programRepository ?? ProgramRepository()
    self.exerciseRepository = exerciseRepository ?? ExerciseRepository()
    self.backupRepository = backupRepository ?? ActiveSessionBackupRepository()
    self.restTimerScheduler = restTimerScheduler ?? RestTimerNotificationScheduler()
    self.weightUnit = weightUnit
    self.now = now
}
```

**Update `start()`** — add reference-building after `saveBackup()`:

```swift
// Existing end of the do-block in start():
            setSuccess(
                session: session,
                day: day,
                programExercises: orderedProgramExercises,
                exerciseLookup: exerciseLookup,
                rowStates: rowStates,
                startedAt: startedAt,
                currentExerciseIndex: 0,
                finishedExerciseIds: [],
                defaultWeights: defaultWeights
            )
            saveBackup()
            // ADD:
            await buildLastSessionReferences(session: session, programExercises: orderedProgramExercises)
```

**Update `restore()`** — add reference-building after `saveBackup()`:

```swift
// End of restore():
        moveToFirstUnfinishedExercise()
        saveBackup()
        // ADD:
        await buildLastSessionReferences(session: snapshot.session, programExercises: snapshot.programExercises)
```

**Update `startRestTimer()`** — add scheduler call after `saveBackup()`:

```swift
func startRestTimer(seconds: Int, sourceSetId: UUID) {
    let startedAt = now()
    activeTimer = RestTimerState(
        sourceSetId: sourceSetId,
        targetSeconds: seconds,
        startedAt: startedAt,
        endsAt: startedAt.addingTimeInterval(TimeInterval(seconds))
    )
    saveBackup()
    guard case let .success(data) = state else { return }
    let sessionId = data.session.id
    Task { @MainActor in
        await restTimerScheduler.schedule(after: TimeInterval(seconds), sessionId: sessionId)
        if UIApplication.shared.applicationState != .active {
            await restTimerScheduler.requestAuthorizationIfNeeded()
        }
    }
}
```

**Update `stopRestTimer()`** — add scheduler cancel:

```swift
func stopRestTimer() {
    if case let .success(data) = state {
        restTimerScheduler.cancel(sessionId: data.session.id)
    }
    activeTimer = nil
    saveBackup()
}
```

**Update `finishSession()`** — add `cancelAll()` after `backupRepository.clearBackup()`:

```swift
            backupRepository.clearBackup()
            restTimerScheduler.cancelAll()   // ADD
            activeTimer = nil
            updateSessionEndedAt(now())
```

**Add the private helper** at the end of the class body:

```swift
private func buildLastSessionReferences(
    session: WorkoutSession,
    programExercises: [ProgramExercise]
) async {
    do {
        let history = try await workoutRepository.fetchHistory(limit: 10)
        let completed = history.filter { $0.isComplete && $0.id != session.id }
        var setsDict: [UUID: [WorkoutSet]] = [:]
        for past in completed {
            setsDict[past.id] = try await workoutRepository.fetchSets(sessionId: past.id)
        }
        let service = LastSessionLookupService()
        var refs: [UUID: LastSessionReference?] = [:]
        for pe in programExercises {
            refs[pe.id] = service.reference(
                for: pe.id,
                exerciseId: pe.exerciseId,
                in: completed,
                sets: setsDict,
                unit: weightUnit
            )
        }
        lastSessionReferences = refs
    } catch {
        workoutLogger.debug("buildLastSessionReferences failed: \(String(describing: error))")
    }
}
```

- [ ] **Step 4.7: Run ViewModel tests — they should pass**

```bash
xcodebuild test \
  -project Gymbros.xcodeproj \
  -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:GymbrosTests/WorkoutSessionViewModelTests
```

Expected: all tests PASS (existing 20 + 3 new = 23 total).

- [ ] **Step 4.8: Commit**

```bash
git add Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift \
        GymbrosTests/WorkoutSessionViewModelTests.swift
git commit -m "feat(s05p): wire restTimerScheduler + lastSessionReferences into WorkoutSessionViewModel"
```

---

## Task 5: RestTimerRingView pulse animation

**Files:**
- Modify: `Gymbros/Presentation/Workout/RestTimerRingView.swift`

- [ ] **Step 5.1: Add scale state and apply scaleEffect**

In `Gymbros/Presentation/Workout/RestTimerRingView.swift`, add a `@State private var scale: Double = 1.0` after the existing `@State` properties, and wrap the ZStack (ring) in `scaleEffect`:

Change:
```swift
@State private var currentTime = Date()
private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
```

To:
```swift
@State private var currentTime = Date()
@State private var scale: Double = 1.0
private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
```

Change the ZStack:
```swift
ZStack {
    // ...ring content...
}
.frame(width: 200, height: 200)
```

To:
```swift
ZStack {
    // ...ring content...
}
.frame(width: 200, height: 200)
.scaleEffect(scale)
```

- [ ] **Step 5.2: Trigger pulse in onReceive**

In the `.onReceive(timer)` block, change the completion handler:

```swift
// Before:
if state.remainingSeconds(at: input) <= 0 {
    triggerHaptic()
    timer.upstream.connect().cancel()
}

// After:
if state.remainingSeconds(at: input) <= 0 {
    triggerHaptic()
    timer.upstream.connect().cancel()
    if !UIAccessibility.isReduceMotionEnabled {
        withAnimation(
            .spring(response: 0.25, dampingFraction: 0.5)
             .repeatCount(2, autoreverses: true),
            completionCriteria: .logicallyComplete
        ) {
            scale = 1.08
        } completion: {
            scale = 1.0
        }
    }
}
```

- [ ] **Step 5.3: Build to verify**

```bash
xcodebuild \
  -project Gymbros.xcodeproj \
  -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5.4: Commit**

```bash
git add Gymbros/Presentation/Workout/RestTimerRingView.swift
git commit -m "feat(s05p): add completion pulse animation to RestTimerRingView"
```

---

## Task 6: WorkoutExercisePageView reference row + view wiring

**Files:**
- Modify: `Gymbros/Presentation/Workout/WorkoutExercisePageView.swift`
- Modify: `Gymbros/Presentation/Workout/WorkoutSessionView.swift`
- Modify: `Gymbros/Presentation/Workout/WorkoutSessionScreen.swift`

- [ ] **Step 6.1: Add lastSessionReference to WorkoutExercisePageView**

In `Gymbros/Presentation/Workout/WorkoutExercisePageView.swift`, add a new property after `@Environment(AppPreferences.self)`:

```swift
var lastSessionReference: LastSessionReference?
```

The full property list becomes:
```swift
let section: WorkoutExerciseSection
var lastSessionReference: LastSessionReference?
@Environment(AppPreferences.self) private var appPreferences

var onAddSet: (UUID) -> Void
var onUpdateSet: (UUID, String, String, Double?) -> Void
var onCompleteSet: (UUID) -> Void
var onDeleteSet: (UUID) -> Void
var onFinishExercise: (UUID) -> Void
```

- [ ] **Step 6.2: Add the reference row computed property**

Add this private computed property to `WorkoutExercisePageView`:

```swift
@ViewBuilder
private var referenceRow: some View {
    if let ref = lastSessionReference {
        HStack(spacing: 4) {
            Text(verbatim: mainReferenceText(ref))
                .foregroundStyle(.secondary)
            if ref.isFallback {
                Text("workout.last_session.fallback_hint")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption.monospacedDigit())
        .frame(maxWidth: .infinity, alignment: .leading)
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.horizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("accessibility.workout.last_session \(mainReferenceText(ref))"))
    } else {
        Text("workout.last_session.empty")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
            .padding(.horizontal)
            .accessibilityHidden(true)
    }
}

private func mainReferenceText(_ ref: LastSessionReference) -> String {
    let repsString = ref.reps.map { "\($0)" }.joined(separator: ", ")
    if let weight = ref.weight {
        let weightStr = weight.formatted(.number.precision(.fractionLength(0...2)))
            + " " + ref.unit.localizedAbbreviation
        return String(format: String(localized: "workout.last_session.reference"), weightStr, repsString)
    } else {
        return String(format: String(localized: "workout.last_session.reference.bodyweight"), repsString)
    }
}
```

- [ ] **Step 6.3: Insert referenceRow into the body**

In `WorkoutExercisePageView.body`, insert `referenceRow` between `exerciseHeader` and the sets `VStack`:

```swift
// Before:
VStack(spacing: 24) {
    exerciseHeader

    VStack(spacing: 0) {

// After:
VStack(spacing: 24) {
    exerciseHeader
    referenceRow

    VStack(spacing: 0) {
```

- [ ] **Step 6.4: Update WorkoutSessionView to accept + thread lastSessionReferences**

In `Gymbros/Presentation/Workout/WorkoutSessionView.swift`, add a new property with default value after `var isFinishing: Bool = false`:

```swift
var lastSessionReferences: [UUID: LastSessionReference?] = [:]
```

In the `ForEach` block that creates `WorkoutExercisePageView`, add the reference:

```swift
// Before:
WorkoutExercisePageView(
    section: data.exerciseSections[index],
    onAddSet: onAddSet,
    ...
)

// After:
WorkoutExercisePageView(
    section: data.exerciseSections[index],
    lastSessionReference: lastSessionReferences[data.exerciseSections[index].programExercise.id] ?? nil,
    onAddSet: onAddSet,
    ...
)
```

- [ ] **Step 6.5: Update WorkoutSessionScreen to pass lastSessionReferences**

In `Gymbros/Presentation/Workout/WorkoutSessionScreen.swift`, add `lastSessionReferences:` to the `WorkoutSessionView(...)` call:

```swift
WorkoutSessionView(
    state: viewModel.state,
    activeTimer: viewModel.activeTimer,
    isFinishing: viewModel.isFinishing,
    lastSessionReferences: viewModel.lastSessionReferences,   // ADD
    pendingRestore: viewModel.pendingRestore != nil,
    currentExerciseIndex: currentExerciseIndex,
    ...
)
```

- [ ] **Step 6.6: Build to verify**

```bash
xcodebuild \
  -project Gymbros.xcodeproj \
  -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 6.7: Commit**

```bash
git add Gymbros/Presentation/Workout/WorkoutExercisePageView.swift \
        Gymbros/Presentation/Workout/WorkoutSessionView.swift \
        Gymbros/Presentation/Workout/WorkoutSessionScreen.swift
git commit -m "feat(s05p): add last-session reference row to WorkoutExercisePageView"
```

---

## Task 7: Localization keys

**Files:**
- Modify: `Gymbros/Resources/Localizable.xcstrings`

- [ ] **Step 7.1: Add new keys**

Open `Gymbros/Resources/Localizable.xcstrings` and add the following 7 key entries inside the `"strings"` object. Add them in alphabetical order (find `"workout.restore"` and insert before it):

```json
"accessibility.workout.last_session %@" : {
  "comment" : "Accessibility label for the last session reference row",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Last session: %@"
      }
    },
    "th" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "เซสชั่นล่าสุด: %@"
      }
    }
  }
},
"workout.last_session.empty" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "No previous data"
      }
    },
    "th" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "ยังไม่มีข้อมูลก่อนหน้า"
      }
    }
  }
},
"workout.last_session.fallback_hint" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "From a different program"
      }
    },
    "th" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "จากโปรแกรมก่อนหน้า"
      }
    }
  }
},
"workout.last_session.reference" : {
  "comment" : "Format: weight string × reps list e.g. 'Last: 60 kg × 8, 8, 7'",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Last: %1$@ × %2$@"
      }
    },
    "th" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "ครั้งก่อน: %1$@ × %2$@"
      }
    }
  }
},
"workout.last_session.reference.bodyweight" : {
  "comment" : "Format: reps list for bodyweight exercises e.g. 'Last: 8, 8, 7 reps'",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Last: %@ reps"
      }
    },
    "th" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "ครั้งก่อน: %@ ครั้ง"
      }
    }
  }
},
"workout.rest_timer.notification.body" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Time for your next set."
      }
    },
    "th" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "ถึงเวลาเซ็ตต่อไป"
      }
    }
  }
},
"workout.rest_timer.notification.title" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Rest's up"
      }
    },
    "th" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "พักครบแล้ว"
      }
    }
  }
},
```

- [ ] **Step 7.2: Validate the JSON**

```bash
jq empty Gymbros/Resources/Localizable.xcstrings && echo "JSON valid"
```

Expected: `JSON valid`.

- [ ] **Step 7.3: Commit**

```bash
git add Gymbros/Resources/Localizable.xcstrings
git commit -m "feat(s05p): add localization keys for rest timer notifications and last-session reference"
```

---

## Task 8: Full test suite + smoke test

**Files:** None — verification only.

- [ ] **Step 8.1: Run the full test suite**

```bash
xcodebuild test \
  -project Gymbros.xcodeproj \
  -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: all tests PASS. Fix any regressions before proceeding.

- [ ] **Step 8.2: Smoke test checklist**

Run the app on iPhone 17e simulator and verify each item:

```
1. Start a workout with an exercise that has previous logged sessions.
   → Reference row shows "Last: X kg × n, n, n" with correct unit (kg or lb).

2. Start a workout with a brand-new exercise.
   → Reference row shows "No previous data" (muted, not hidden).

3. Tap a weight field, enter a value, tap anywhere outside it.
   → Keyboard dismisses. Value is retained.

4. Open keyboard then scroll the page.
   → Keyboard dismisses interactively.

5. Open ProgramExerciseEditorView, tap a field, tap outside.
   → Keyboard dismisses. No value loss.

6. Complete a set. Rest timer starts (Reduce Motion OFF).
   → Timer ring pulses twice on completion.

7. Repeat with Reduce Motion ON (Settings > Accessibility > Motion).
   → Timer completes cleanly, no scale animation.

8. Complete a set, switch to Notes app, wait for timer to expire.
   → Local notification appears with "Rest's up" (en) or "พักครบแล้ว" (th).

9. Complete a set, switch away, then return and stop timer before it expires.
   → No notification fires.

10. Finish the workout.
    → No lingering rest-timer notifications remain pending.

11. Switch device language to Thai; repeat items 1–2 and 8.
    → Thai strings display correctly.
```

- [ ] **Step 8.3: Update STANDUP.md**

Update `STANDUP.md` with:
- Last-updated date to today
- HEAD SHA after final commit
- "What was done" = Sprint S05p complete
- "Next up" = Sprint S06 (Next Best Session / Smart Comeback)
- Close any open S05p follow-ups in the open follow-ups list

- [ ] **Step 8.4: Update GYMTRACK.md sprint tracking table**

In `.claude/GYMTRACK.md §9`, add Sprint S05p row:

```
| 5p | Phase 1 Polish | ✓ | — | Rest timer notifications, keyboard dismiss, last-session reference |
```

Also mark the Phase 1 Trial Feedback backlog items (rest timer background, keyboard dismissal, last-session kg/reps) as `✓` in the backlog section.

---

## Self-Review Notes

- All 3 spec requirements (rest timer notifications, keyboard dismissal, last-session reference) are covered by Tasks 1–7.
- `LastSessionReference.Label.baseline` is declared (Task 1) but not wired — reserved for Sprint 6 per spec.
- `View+DismissKeyboard` is applied to all 3 specified views (Task 3).
- `restTimerScheduler.cancelAll()` is called in both `finishSession()` and `stopRestTimer()` cancels per session (Task 4).
- All 7 localization keys have both Thai and English (Task 7).
- Pulse animation is gated on `!UIAccessibility.isReduceMotionEnabled` (Task 5).
- `buildLastSessionReferences` is called in both `start()` and `restore()` (Task 4).
- `WorkoutExercisePageView.lastSessionReference` has a default of `nil` so existing previews compile unchanged (Task 6).
- `WorkoutSessionView.lastSessionReferences` has a default of `[:]` so existing previews compile unchanged (Task 6).
