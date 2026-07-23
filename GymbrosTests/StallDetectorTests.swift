import Testing
import Foundation
@testable import Gymbros

@Suite("StallDetector")
struct StallDetectorTests {
    private let exerciseId = UUID()

    private func session(daysAgo: Double) -> WorkoutSession {
        let start = Date.now.addingTimeInterval(-daysAgo * 86_400)
        return WorkoutSession(
            id: UUID(),
            userId: UUID(),
            programDayId: nil,
            startedAt: start,
            endedAt: start.addingTimeInterval(3_000),
            notes: nil,
            createdAt: start
        )
    }

    private func set(sessionId: UUID, exerciseId: UUID? = nil, weight: Double, rpe: Double?) -> WorkoutSet {
        WorkoutSet(
            id: UUID(),
            sessionId: sessionId,
            exerciseId: exerciseId ?? self.exerciseId,
            programExerciseId: nil,
            setNumber: 1,
            weight: weight,
            reps: 8,
            rpe: rpe,
            targetRestSeconds: nil,
            actualRestSeconds: nil,
            restStartedAt: nil,
            restEndedAt: nil,
            completedAt: Date.now,
            notes: nil
        )
    }

    @Test func sameWeightFourSessionsIsStalled() {
        let sessions = [1, 3, 5, 7].map { session(daysAgo: Double($0)) }
        var sets: [UUID: [WorkoutSet]] = [:]
        for s in sessions { sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: 7.0)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets))
    }

    @Test func fewerThanFourSessionsIsNotStalled() {
        let sessions = [1, 3, 5].map { session(daysAgo: Double($0)) }
        var sets: [UUID: [WorkoutSet]] = [:]
        for s in sessions { sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: 7.0)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets) == false)
    }

    @Test func weightDiffersAcrossSessionsIsNotStalled() {
        let sessions = [1, 3, 5, 7].map { session(daysAgo: Double($0)) }
        var sets: [UUID: [WorkoutSet]] = [:]
        let weights: [Double] = [80, 80, 77.5, 80]
        for (s, weight) in zip(sessions, weights) { sets[s.id] = [set(sessionId: s.id, weight: weight, rpe: 7.0)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets) == false)
    }

    @Test func rpeAbove8BlocksStall() {
        let sessions = [1, 3, 5, 7].map { session(daysAgo: Double($0)) }
        var sets: [UUID: [WorkoutSet]] = [:]
        let rpes: [Double?] = [7.0, 7.0, 8.5, 7.0]
        for (s, rpe) in zip(sessions, rpes) { sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: rpe)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets) == false)
    }

    @Test func missingRPEDoesNotBlockStall() {
        let sessions = [1, 3, 5, 7].map { session(daysAgo: Double($0)) }
        var sets: [UUID: [WorkoutSet]] = [:]
        let rpes: [Double?] = [7.0, nil, nil, 7.0]
        for (s, rpe) in zip(sessions, rpes) { sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: rpe)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets))
    }

    @Test func sessionsWithoutThisExerciseAreIgnored() {
        let otherExerciseId = UUID()
        let qualifying = [1, 3, 5, 7].map { session(daysAgo: Double($0)) }
        let noise = [2, 4].map { session(daysAgo: Double($0)) }
        var sets: [UUID: [WorkoutSet]] = [:]
        for s in qualifying {
            sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: 7.0)]
        }
        for s in noise {
            sets[s.id] = [set(sessionId: s.id, exerciseId: otherExerciseId, weight: 999, rpe: 7.0)]
        }

        let allSessions = (qualifying + noise).sorted { $0.startedAt > $1.startedAt }
        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: allSessions, sets: sets))
    }
}
