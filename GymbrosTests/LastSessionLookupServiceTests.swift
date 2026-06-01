import Foundation
import Testing
@testable import Gymbros

@Suite("LastSessionLookupService")
struct LastSessionLookupServiceTests {
    private let service = LastSessionLookupService()
    private let programExerciseId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let exerciseId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let userId = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    @Test func returnsNilWhenNoHistory() {
        let result = service.reference(
            for: programExerciseId,
            exerciseId: exerciseId,
            in: [],
            sets: [:],
            unit: .kg
        )

        #expect(result == nil)
    }

    @Test func returnsReferenceForProgramExerciseIdMatch() {
        let session = makeSession()
        let sets = [
            makeSet(sessionId: session.id, programExerciseId: programExerciseId, setNumber: 2, reps: 8),
            makeSet(sessionId: session.id, programExerciseId: programExerciseId, setNumber: 1, reps: 9),
            makeSet(sessionId: session.id, programExerciseId: programExerciseId, setNumber: 3, reps: 7)
        ]

        let result = service.reference(
            for: programExerciseId,
            exerciseId: exerciseId,
            in: [session],
            sets: [session.id: sets],
            unit: .kg
        )

        #expect(result?.weight == 60)
        #expect(result?.reps == [9, 8, 7])
        #expect(result?.isFallback == false)
        #expect(result?.label == .last)
    }

    @Test func fallsBackToExerciseIdWhenProgramExerciseDoesNotMatch() {
        let session = makeSession()
        let set = makeSet(sessionId: session.id, programExerciseId: UUID(), setNumber: 1, reps: 5)

        let result = service.reference(
            for: programExerciseId,
            exerciseId: exerciseId,
            in: [session],
            sets: [session.id: [set]],
            unit: .kg
        )

        #expect(result?.reps == [5])
        #expect(result?.isFallback == true)
    }

    @Test func ignoresIncompleteSessions() {
        let session = makeSession(endedAt: nil)
        let set = makeSet(sessionId: session.id, programExerciseId: programExerciseId, setNumber: 1, reps: 8)

        let result = service.reference(
            for: programExerciseId,
            exerciseId: exerciseId,
            in: [session],
            sets: [session.id: [set]],
            unit: .kg
        )

        #expect(result == nil)
    }

    @Test func convertsWeightToPounds() {
        let session = makeSession()
        let set = makeSet(sessionId: session.id, programExerciseId: programExerciseId, setNumber: 1, reps: 8)

        let result = service.reference(
            for: programExerciseId,
            exerciseId: exerciseId,
            in: [session],
            sets: [session.id: [set]],
            unit: .lb
        )

        #expect(result?.unit == .lb)
        #expect(abs((result?.weight ?? 0) - 132.2773573) < 0.001)
    }

    @Test func treatsZeroWeightAsBodyweight() {
        let session = makeSession()
        let set = makeSet(
            sessionId: session.id,
            programExerciseId: programExerciseId,
            setNumber: 1,
            weight: 0,
            reps: 10
        )

        let result = service.reference(
            for: programExerciseId,
            exerciseId: exerciseId,
            in: [session],
            sets: [session.id: [set]],
            unit: .kg
        )

        #expect(result?.weight == nil)
        #expect(result?.reps == [10])
    }

    @Test func picksNewestSession() {
        let older = makeSession(startedAt: Date(timeIntervalSince1970: 100), endedAt: Date(timeIntervalSince1970: 200))
        let newer = makeSession(startedAt: Date(timeIntervalSince1970: 300), endedAt: Date(timeIntervalSince1970: 400))

        let result = service.reference(
            for: programExerciseId,
            exerciseId: exerciseId,
            in: [older, newer],
            sets: [
                older.id: [makeSet(sessionId: older.id, programExerciseId: programExerciseId, setNumber: 1, weight: 60, reps: 8)],
                newer.id: [makeSet(sessionId: newer.id, programExerciseId: programExerciseId, setNumber: 1, weight: 80, reps: 5)]
            ],
            unit: .kg
        )

        #expect(result?.weight == 80)
        #expect(result?.reps == [5])
    }

    private func makeSession(
        id: UUID = UUID(),
        startedAt: Date = Date(timeIntervalSince1970: 1_000),
        endedAt: Date? = Date(timeIntervalSince1970: 2_000)
    ) -> WorkoutSession {
        WorkoutSession(
            id: id,
            userId: userId,
            programDayId: nil,
            startedAt: startedAt,
            endedAt: endedAt,
            notes: nil,
            createdAt: startedAt
        )
    }

    private func makeSet(
        sessionId: UUID,
        programExerciseId: UUID?,
        setNumber: Int,
        weight: Double = 60,
        reps: Int
    ) -> WorkoutSet {
        WorkoutSet(
            id: UUID(),
            sessionId: sessionId,
            exerciseId: exerciseId,
            programExerciseId: programExerciseId,
            setNumber: setNumber,
            weight: weight,
            reps: reps,
            rpe: nil,
            targetRestSeconds: nil,
            actualRestSeconds: nil,
            restStartedAt: nil,
            restEndedAt: nil,
            completedAt: Date(),
            notes: nil
        )
    }
}
