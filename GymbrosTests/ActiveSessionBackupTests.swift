import Foundation
import Testing
@testable import Gymbros

@MainActor
@Suite("Active Session Backup")
struct ActiveSessionBackupTests {
    @Test func backupRoundTripsSnapshot() throws {
        let suiteName = "ActiveSessionBackupTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let store = ActiveSessionBackupStore(userDefaults: userDefaults, key: "test-active-session")
        let snapshot = makeSnapshot()

        guard case .success = store.save(snapshot) else {
            throw AppError.unknown(debugID: "save-failed")
        }
        let restored = try successValue(store.load())

        #expect(restored == snapshot)
        #expect(restored.finishedExerciseIds == [ProgramSamples.benchProgramExerciseId])
        #expect(restored.currentExerciseIndex == 1)
        #expect(restored.defaultWeights?[ProgramSamples.benchProgramExerciseId] == 80)
    }

    @Test func versionMismatchReturnsDecodingError() throws {
        let suiteName = "ActiveSessionBackupTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let store = ActiveSessionBackupStore(userDefaults: userDefaults, key: "test-active-session")
        var snapshot = makeSnapshot()
        snapshot.version = ActiveSessionSnapshot.currentVersion + 1

        guard case .success = store.save(snapshot) else {
            throw AppError.unknown(debugID: "save-failed")
        }

        guard case .failure(let error) = store.load() else {
            throw AppError.unknown(debugID: "expected-failure")
        }
        #expect(error == .decoding)
    }

    @Test func activeWorkoutWidgetDataUsesBackupForResumeSummary() throws {
        var snapshot = makeSnapshot()
        snapshot.finishedExerciseIds = []
        snapshot.currentExerciseIndex = 0
        snapshot.rowStates[0].isCompleted = false

        let data = try #require(ActiveWorkoutWidgetData(
            snapshot: snapshot,
            weightUnit: .kg,
            date: ProgramSamples.createdAt
        ))

        guard case .resting(let endsAt) = data.status else {
            throw AppError.unknown(debugID: "expected-resting")
        }
        #expect(endsAt == ProgramSamples.createdAt.addingTimeInterval(90))
        #expect(data.workoutName == "Upper A")
        #expect(data.exerciseName == "Bench Press")
        #expect(data.prescriptionText == "80 kg - Set 1/3 - 8 reps")
        #expect(data.route.programDayId == ProgramSamples.upperDayId)
        #expect(data.route.programExerciseId == ProgramSamples.benchProgramExerciseId)
        #expect(data.route.sessionId == snapshot.session.id)
    }

    @Test func activeWorkoutWidgetDataFormatsCompactStatuses() throws {
        var workingSnapshot = makeSnapshot()
        workingSnapshot.activeTimer = nil
        workingSnapshot.finishedExerciseIds = []
        workingSnapshot.rowStates[0].isCompleted = false
        let working = try #require(ActiveWorkoutWidgetData(
            snapshot: workingSnapshot,
            weightUnit: .kg,
            date: ProgramSamples.createdAt.addingTimeInterval(3)
        ))
        #expect(working.compactStatusText == "Workout 3s")

        var restingSnapshot = workingSnapshot
        restingSnapshot.activeTimer = RestTimerState(
            sourceSetId: restingSnapshot.rowStates[0].id,
            targetSeconds: 90,
            startedAt: ProgramSamples.createdAt,
            endsAt: ProgramSamples.createdAt.addingTimeInterval(90)
        )
        let resting = try #require(ActiveWorkoutWidgetData(
            snapshot: restingSnapshot,
            weightUnit: .kg,
            date: ProgramSamples.createdAt.addingTimeInterval(45)
        ))
        #expect(resting.compactStatusText == "Rest 0:45")

        let ready = try #require(ActiveWorkoutWidgetData(
            snapshot: restingSnapshot,
            weightUnit: .kg,
            date: ProgramSamples.createdAt.addingTimeInterval(91)
        ))
        #expect(ready.compactStatusText == "Ready")
    }

    @Test func activeWorkoutWidgetSuppressionHidesWidgetWithoutClearingBackup() async throws {
        let suiteName = "ActiveWorkoutWidgetSuppression.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let snapshot = makeSnapshot()
        let backupRepository = FakeActiveWidgetBackupRepository(loadResult: .success(snapshot))
        let scheduler = FakeActiveWidgetRestTimerScheduler()
        let liveActivity = FakeActiveWidgetLiveActivityController()
        let viewModel = ActiveWorkoutWidgetViewModel(
            backupRepository: backupRepository,
            restTimerScheduler: scheduler,
            liveActivityController: liveActivity,
            userDefaults: userDefaults,
            suppressedSessionKey: "suppressed-test"
        )

        viewModel.refresh()
        #expect(viewModel.visibleSnapshot?.session.id == snapshot.session.id)

        await viewModel.stopAndSuppressCurrentSession()

        #expect(viewModel.visibleSnapshot == nil)
        #expect(backupRepository.clearCount == 0)
        #expect(scheduler.cancelledSessionIds == [snapshot.session.id])
        #expect(liveActivity.endCount == 1)
        #expect(userDefaults.string(forKey: "suppressed-test") == snapshot.session.id.uuidString)
    }

    @Test func activeWorkoutWidgetSuppressionDoesNotHideNewSession() throws {
        let suiteName = "ActiveWorkoutWidgetNewSession.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        userDefaults.set(
            UUID(uuidString: "99999999-0000-0000-0000-000000000099")!.uuidString,
            forKey: "suppressed-test"
        )
        let snapshot = makeSnapshot()
        let viewModel = ActiveWorkoutWidgetViewModel(
            backupRepository: FakeActiveWidgetBackupRepository(loadResult: .success(snapshot)),
            restTimerScheduler: FakeActiveWidgetRestTimerScheduler(),
            liveActivityController: FakeActiveWidgetLiveActivityController(),
            userDefaults: userDefaults,
            suppressedSessionKey: "suppressed-test"
        )

        viewModel.refresh()

        #expect(viewModel.visibleSnapshot?.session.id == snapshot.session.id)
        #expect(viewModel.suppressedSessionId == nil)
        #expect(userDefaults.string(forKey: "suppressed-test") == nil)
    }

    @Test func openingWorkoutScreenClearsWidgetSuppression() async throws {
        let suiteName = "ActiveWorkoutWidgetVisible.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let snapshot = makeSnapshot()
        let viewModel = ActiveWorkoutWidgetViewModel(
            backupRepository: FakeActiveWidgetBackupRepository(loadResult: .success(snapshot)),
            restTimerScheduler: FakeActiveWidgetRestTimerScheduler(),
            liveActivityController: FakeActiveWidgetLiveActivityController(),
            userDefaults: userDefaults,
            suppressedSessionKey: "suppressed-test"
        )
        viewModel.refresh()
        await viewModel.stopAndSuppressCurrentSession()

        viewModel.setWorkoutSessionVisible(true)
        #expect(viewModel.suppressedSessionId == nil)
        #expect(viewModel.visibleSnapshot == nil)

        viewModel.setWorkoutSessionVisible(false)
        #expect(viewModel.visibleSnapshot?.session.id == snapshot.session.id)
    }

    private func successValue(_ result: Result<ActiveSessionSnapshot?, AppError>) throws -> ActiveSessionSnapshot {
        guard case .success(let snapshot?) = result else {
            throw AppError.unknown(debugID: "expected-snapshot")
        }
        return snapshot
    }
}

func makeSnapshot(
    sessionId: UUID = UUID(uuidString: "99999999-0000-0000-0000-000000000001")!
) -> ActiveSessionSnapshot {
    let session = WorkoutSession(
        id: sessionId,
        userId: ProgramSamples.userId,
        programDayId: ProgramSamples.upperDayId,
        startedAt: ProgramSamples.createdAt,
        endedAt: nil,
        notes: nil,
        createdAt: ProgramSamples.createdAt
    )
    let row = ActiveSessionSetSnapshot(
        id: UUID(uuidString: "99999999-0000-0000-0000-000000000002")!,
        exerciseId: ProgramSamples.benchExerciseId,
        programExerciseId: ProgramSamples.benchProgramExerciseId,
        setNumber: 1,
        weightText: "80",
        repsText: "8",
        rpe: 7.5,
        targetRestSeconds: 90,
        isCompleted: true
    )
    var day = ProgramSamples.days[0]
    day.exercises = []
    return ActiveSessionSnapshot(
        session: session,
        day: day,
        programExercises: [ProgramSamples.benchProgramExercise],
        exerciseLookup: [ProgramSamples.benchExerciseId: ProgramSamples.benchPress],
        rowStates: [row],
        activeTimer: RestTimerState(
            sourceSetId: row.id,
            targetSeconds: 90,
            startedAt: ProgramSamples.createdAt,
            endsAt: ProgramSamples.createdAt.addingTimeInterval(90)
        ),
        finishedExerciseIds: [ProgramSamples.benchProgramExerciseId],
        currentExerciseIndex: 1,
        defaultWeights: [ProgramSamples.benchProgramExerciseId: 80],
        updatedAt: ProgramSamples.createdAt
    )
}

@MainActor
private final class FakeActiveWidgetBackupRepository: ActiveSessionBackupRepositoryProviding {
    var loadResult: Result<ActiveSessionSnapshot?, AppError>
    var clearCount = 0

    init(loadResult: Result<ActiveSessionSnapshot?, AppError>) {
        self.loadResult = loadResult
    }

    func loadBackup() -> Result<ActiveSessionSnapshot?, AppError> {
        loadResult
    }

    func saveBackup(_ snapshot: ActiveSessionSnapshot) -> Result<Void, AppError> {
        .success(())
    }

    func clearBackup() {
        clearCount += 1
    }
}

@MainActor
private final class FakeActiveWidgetRestTimerScheduler: RestTimerScheduling {
    var cancelAllCount = 0
    var cancelledSessionIds: [UUID] = []

    func requestAuthorizationIfNeeded() async {}
    func schedule(
        after seconds: TimeInterval,
        sessionId: UUID,
        programDayId: UUID?,
        programExerciseId: UUID?
    ) async {}
    func cancel(sessionId: UUID) {
        cancelledSessionIds.append(sessionId)
    }
    func cancelAll() {
        cancelAllCount += 1
    }
}

@MainActor
private final class FakeActiveWidgetLiveActivityController: RestTimerLiveActivityControlling {
    var endCount = 0

    func start(
        sessionId: UUID,
        programDayId: UUID?,
        state: RestTimerActivityAttributes.ContentState
    ) async {}
    func update(_ state: RestTimerActivityAttributes.ContentState) async {}
    func end() async {
        endCount += 1
    }
}
