import Foundation
import Testing
@testable import Gymbros

@Suite("ProgressiveOverloadEngine")
struct ProgressiveOverloadEngineTests {
    private let engine = ProgressiveOverloadEngine()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let exerciseId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    @Test func nilWithNoSessions() {
        let suggestion = engine.nextWeightSuggestion(
            forExerciseId: exerciseId,
            recentSessions: [],
            sets: [:],
            now: now
        )
        #expect(suggestion == nil)
    }

    @Test func nilWithOneSession() {
        let (sessions, sets) = makeHistory([(daysAgo: 3, weight: 80, reps: 8, rpe: 7.0)])
        let suggestion = engine.nextWeightSuggestion(
            forExerciseId: exerciseId,
            recentSessions: sessions,
            sets: sets,
            now: now
        )
        #expect(suggestion == nil)
    }

    @Test func suggestsIncrementWhenRPELowAndTargetRepsHit() {
        let (sessions, sets) = makeHistory([
            (daysAgo: 3, weight: 80, reps: 8, rpe: 7.0),
            (daysAgo: 7, weight: 80, reps: 8, rpe: 7.5)
        ])
        let suggestion = engine.nextWeightSuggestion(
            forExerciseId: exerciseId,
            recentSessions: sessions,
            sets: sets,
            targetRepsMin: 8,
            now: now
        )
        #expect(suggestion == 82.5)
    }

    @Test func nilWhenRPELowButTargetRepsMissed() {
        let (sessions, sets) = makeHistory([
            (daysAgo: 3, weight: 80, reps: 5, rpe: 7.0),
            (daysAgo: 7, weight: 80, reps: 8, rpe: 7.5)
        ])
        let suggestion = engine.nextWeightSuggestion(
            forExerciseId: exerciseId,
            recentSessions: sessions,
            sets: sets,
            targetRepsMin: 8,
            now: now
        )
        #expect(suggestion == nil)
    }

    @Test func holdsWhenRPEModerate() {
        let (sessions, sets) = makeHistory([
            (daysAgo: 3, weight: 80, reps: 8, rpe: 7.8),
            (daysAgo: 7, weight: 80, reps: 8, rpe: 7.5)
        ])
        let suggestion = engine.nextWeightSuggestion(
            forExerciseId: exerciseId,
            recentSessions: sessions,
            sets: sets,
            targetRepsMin: 8,
            now: now
        )
        #expect(suggestion == 80)
    }

    @Test func nilWhenRPEHigh() {
        let (sessions, sets) = makeHistory([
            (daysAgo: 3, weight: 80, reps: 8, rpe: 8.5),
            (daysAgo: 7, weight: 80, reps: 8, rpe: 7.5)
        ])
        let suggestion = engine.nextWeightSuggestion(
            forExerciseId: exerciseId,
            recentSessions: sessions,
            sets: sets,
            targetRepsMin: 8,
            now: now
        )
        #expect(suggestion == nil)
    }

    @Test func nilWhenRPEMissing() {
        let (sessions, sets) = makeHistory([
            (daysAgo: 3, weight: 80, reps: 8, rpe: nil),
            (daysAgo: 7, weight: 80, reps: 8, rpe: 7.5)
        ])
        let suggestion = engine.nextWeightSuggestion(
            forExerciseId: exerciseId,
            recentSessions: sessions,
            sets: sets,
            targetRepsMin: 8,
            now: now
        )
        #expect(suggestion == nil)
    }

    @Test func nilWhenSessionsOlderThanSixtyDays() {
        let (sessions, sets) = makeHistory([
            (daysAgo: 65, weight: 80, reps: 8, rpe: 7.0),
            (daysAgo: 70, weight: 80, reps: 8, rpe: 7.0)
        ])
        let suggestion = engine.nextWeightSuggestion(
            forExerciseId: exerciseId,
            recentSessions: sessions,
            sets: sets,
            targetRepsMin: 8,
            now: now
        )
        #expect(suggestion == nil)
    }

    // MARK: - Fixtures

    private func makeHistory(
        _ entries: [(daysAgo: Double, weight: Double, reps: Int, rpe: Double?)]
    ) -> ([WorkoutSession], [UUID: [WorkoutSet]]) {
        var sessions: [WorkoutSession] = []
        var sets: [UUID: [WorkoutSet]] = [:]
        for entry in entries {
            let start = now.addingTimeInterval(-entry.daysAgo * 86_400)
            let session = WorkoutSession(
                id: UUID(),
                userId: UUID(),
                programDayId: nil,
                startedAt: start,
                endedAt: start.addingTimeInterval(3_600),
                notes: nil,
                createdAt: start
            )
            sessions.append(session)
            sets[session.id] = [
                WorkoutSet(
                    id: UUID(),
                    sessionId: session.id,
                    exerciseId: exerciseId,
                    programExerciseId: nil,
                    setNumber: 1,
                    weight: entry.weight,
                    reps: entry.reps,
                    rpe: entry.rpe,
                    targetRestSeconds: nil,
                    actualRestSeconds: nil,
                    restStartedAt: nil,
                    restEndedAt: nil,
                    completedAt: start.addingTimeInterval(600),
                    notes: nil
                )
            ]
        }
        return (sessions, sets)
    }
}
