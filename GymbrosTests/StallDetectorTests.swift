import Testing
import Foundation
@testable import Gymbros

@Suite("StallDetector")
struct StallDetectorTests {
    private let exerciseId = UUID()

    private func session(daysAgo: Double, referenceNow: Date) -> WorkoutSession {
        let start = referenceNow.addingTimeInterval(-daysAgo * 86_400)
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

    @Test func sameWeightThreeQualifyingSessionsWithinWindowIsStalled() {
        let now = Date.now
        let sessions = [2, 9, 16].map { session(daysAgo: Double($0), referenceNow: now) }
        var sets: [UUID: [WorkoutSet]] = [:]
        for s in sessions { sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: 7.0)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets, now: now))
    }

    @Test func fewerThanMinimumQualifyingSessionsIsNotStalled() {
        let now = Date.now
        let sessions = [2, 9].map { session(daysAgo: Double($0), referenceNow: now) }
        var sets: [UUID: [WorkoutSet]] = [:]
        for s in sessions { sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: 7.0)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets, now: now) == false)
    }

    @Test func weightDiffersAcrossQualifyingSessionsIsNotStalled() {
        let now = Date.now
        let sessions = [2, 9, 16].map { session(daysAgo: Double($0), referenceNow: now) }
        var sets: [UUID: [WorkoutSet]] = [:]
        let weights: [Double] = [80, 80, 77.5]
        for (s, weight) in zip(sessions, weights) { sets[s.id] = [set(sessionId: s.id, weight: weight, rpe: 7.0)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets, now: now) == false)
    }

    @Test func rpeAbove8BlocksStall() {
        let now = Date.now
        let sessions = [2, 9, 16].map { session(daysAgo: Double($0), referenceNow: now) }
        var sets: [UUID: [WorkoutSet]] = [:]
        let rpes: [Double?] = [7.0, 8.5, 7.0]
        for (s, rpe) in zip(sessions, rpes) { sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: rpe)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets, now: now) == false)
    }

    @Test func missingRPEDoesNotBlockStall() {
        let now = Date.now
        let sessions = [2, 9, 16].map { session(daysAgo: Double($0), referenceNow: now) }
        var sets: [UUID: [WorkoutSet]] = [:]
        let rpes: [Double?] = [7.0, nil, 7.0]
        for (s, rpe) in zip(sessions, rpes) { sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: rpe)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets, now: now))
    }

    @Test func sessionsOutsideWindowAreIgnored() {
        let now = Date.now
        // Only 2 sessions inside the 35-day window; a 3rd same-weight session sits at 40 days
        // ago (outside it) and must not count toward the minimum.
        let inWindow = [2, 16].map { session(daysAgo: Double($0), referenceNow: now) }
        let outOfWindow = session(daysAgo: 40, referenceNow: now)
        var sets: [UUID: [WorkoutSet]] = [:]
        for s in inWindow { sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: 7.0)] }
        sets[outOfWindow.id] = [set(sessionId: outOfWindow.id, weight: 80, rpe: 7.0)]

        let allSessions = inWindow + [outOfWindow]
        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: allSessions, sets: sets, now: now) == false)
    }

    @Test func sessionsWithoutThisExerciseAreIgnored() {
        let now = Date.now
        let otherExerciseId = UUID()
        let qualifying = [2, 9, 16].map { session(daysAgo: Double($0), referenceNow: now) }
        let noise = [5, 12].map { session(daysAgo: Double($0), referenceNow: now) }
        var sets: [UUID: [WorkoutSet]] = [:]
        for s in qualifying {
            sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: 7.0)]
        }
        for s in noise {
            sets[s.id] = [set(sessionId: s.id, exerciseId: otherExerciseId, weight: 999, rpe: 7.0)]
        }

        let allSessions = qualifying + noise
        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: allSessions, sets: sets, now: now))
    }

    @Test func onlyMostRecentQualifyingSessionsAreCheckedForWeightEquality() {
        let now = Date.now
        // Progressed from 70 to 80 partway through the window, then held 80 for the most
        // recent 3 sessions -- this is a real, current stall even though an older weight in
        // the same window differs. Only the most recent minimumQualifyingSessions should
        // matter, not every qualifying session ever seen within the window.
        let sessions = [2, 9, 16, 23].map { session(daysAgo: Double($0), referenceNow: now) }
        var sets: [UUID: [WorkoutSet]] = [:]
        let weights: [Double] = [80, 80, 80, 70]
        for (s, weight) in zip(sessions, weights) { sets[s.id] = [set(sessionId: s.id, weight: weight, rpe: 7.0)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets, now: now))
    }
}
