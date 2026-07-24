import Foundation

struct StallDetector {
    static let windowDays = 35
    static let minimumQualifyingSessions = 3
    static let maxRPEForStall = 8.0

    func isStalled(
        exerciseId: UUID,
        recentSessions: [WorkoutSession],
        sets: [UUID: [WorkoutSet]],
        now: Date
    ) -> Bool {
        let cutoff = now.addingTimeInterval(-TimeInterval(Self.windowDays) * 86_400)
        let qualifyingSessions = recentSessions
            .filter { session in
                let sessionDate = session.endedAt ?? session.startedAt
                guard sessionDate >= cutoff else { return false }
                return (sets[session.id] ?? []).contains { $0.exerciseId == exerciseId }
            }
            .sorted { ($0.endedAt ?? $0.startedAt) > ($1.endedAt ?? $1.startedAt) }
            .prefix(Self.minimumQualifyingSessions)

        guard qualifyingSessions.count == Self.minimumQualifyingSessions else { return false }

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
