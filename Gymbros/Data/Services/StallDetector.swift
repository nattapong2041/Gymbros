import Foundation

struct StallDetector {
    static let sessionThreshold = 4
    static let maxRPEForStall = 8.0

    func isStalled(
        exerciseId: UUID,
        recentSessions: [WorkoutSession],
        sets: [UUID: [WorkoutSet]]
    ) -> Bool {
        let qualifyingSessions = recentSessions
            .filter { session in (sets[session.id] ?? []).contains { $0.exerciseId == exerciseId } }
            .prefix(Self.sessionThreshold)

        guard qualifyingSessions.count == Self.sessionThreshold else { return false }

        let topWeights = qualifyingSessions.map { session in
            (sets[session.id] ?? [])
                .filter { $0.exerciseId == exerciseId }
                .map(\.weight)
                .max() ?? 0
        }
        guard let firstWeight = topWeights.first, topWeights.allSatisfy({ $0 == firstWeight }) else {
            return false
        }

        let anyOverThreshold = qualifyingSessions.contains { session in
            (sets[session.id] ?? [])
                .filter { $0.exerciseId == exerciseId }
                .contains { ($0.rpe ?? 0) > Self.maxRPEForStall }
        }
        return anyOverThreshold == false
    }
}
