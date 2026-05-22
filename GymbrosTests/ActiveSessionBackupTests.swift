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

    private func successValue(_ result: Result<ActiveSessionSnapshot?, AppError>) throws -> ActiveSessionSnapshot {
        guard case .success(let snapshot?) = result else {
            throw AppError.unknown(debugID: "expected-snapshot")
        }
        return snapshot
    }
}

func makeSnapshot() -> ActiveSessionSnapshot {
    let session = WorkoutSession(
        id: UUID(uuidString: "99999999-0000-0000-0000-000000000001")!,
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
