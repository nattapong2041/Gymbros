import Foundation

struct ProgressiveOverloadEngine {
    static let confidenceWindowDays = 60
    static let weightIncrementKg = 2.5

    func nextWeightSuggestion(
        forExerciseId exerciseId: UUID,
        recentSessions: [WorkoutSession],
        sets: [UUID: [WorkoutSet]],
        targetRepsMin: Int? = nil,
        now: Date = .now
    ) -> Double? {
        let windowStart = now.addingTimeInterval(-TimeInterval(Self.confidenceWindowDays) * 86_400)
        let sessionsWithExercise = recentSessions
            .filter { session in
                guard let endedAt = session.endedAt, endedAt >= windowStart else { return false }
                return sets[session.id]?.contains { $0.exerciseId == exerciseId } == true
            }
            .sorted { $0.startedAt > $1.startedAt }

        guard sessionsWithExercise.count >= 2,
              let lastSession = sessionsWithExercise.first,
              let topSet = topSet(forExerciseId: exerciseId, in: sets[lastSession.id] ?? []) else {
            return nil
        }

        guard let rpe = topSet.rpe else { return nil }
        if rpe > 8.0 { return nil }
        if rpe <= 7.0, topSet.reps >= (targetRepsMin ?? 0) {
            return topSet.weight + Self.weightIncrementKg
        }
        if rpe >= 7.5 { return topSet.weight }
        return nil
    }

    private func topSet(forExerciseId exerciseId: UUID, in sets: [WorkoutSet]) -> WorkoutSet? {
        sets
            .filter { $0.exerciseId == exerciseId }
            .max { $0.weight < $1.weight }
    }
}
