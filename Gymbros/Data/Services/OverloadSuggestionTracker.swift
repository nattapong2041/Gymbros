import Foundation

@MainActor
protocol OverloadSuggestionTracking {
    func pendingPreviousWeight(programExerciseId: UUID) -> Double?
    func recordSuggestion(programExerciseId: UUID, previousWeight: Double)
    func clearSuggestion(programExerciseId: UUID)
}

/// Remembers the pre-bump weight for an exercise the Overload Advisor just raised, so the
/// very next session for that exercise can highlight the change and, if it turns out too
/// heavy (RPE >= 9), offer to revert to the value recorded here.
@MainActor
final class OverloadSuggestionTracker: OverloadSuggestionTracking {
    private let userDefaults: UserDefaults
    private let key = "overload_suggestion_previous_weight"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func pendingPreviousWeight(programExerciseId: UUID) -> Double? {
        previousWeights[programExerciseId.uuidString]
    }

    func recordSuggestion(programExerciseId: UUID, previousWeight: Double) {
        var dict = previousWeights
        dict[programExerciseId.uuidString] = previousWeight
        save(dict)
    }

    func clearSuggestion(programExerciseId: UUID) {
        var dict = previousWeights
        dict.removeValue(forKey: programExerciseId.uuidString)
        save(dict)
    }

    private var previousWeights: [String: Double] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func save(_ dict: [String: Double]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        userDefaults.set(data, forKey: key)
    }
}
