import Foundation

@MainActor
protocol OverloadAdvisorSnoozing {
    func isSnoozed(programExerciseId: UUID, now: Date) -> Bool
    func snooze(programExerciseId: UUID, now: Date)
}

@MainActor
final class OverloadAdvisorSnoozeStore: OverloadAdvisorSnoozing {
    static let snoozeDuration: TimeInterval = 14 * 24 * 3600
    private let userDefaults: UserDefaults
    private let key = "overload_advisor_snoozed_until"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func isSnoozed(programExerciseId: UUID, now: Date) -> Bool {
        guard let until = snoozedUntil[programExerciseId.uuidString] else { return false }
        return until > now
    }

    func snooze(programExerciseId: UUID, now: Date) {
        var dict = snoozedUntil
        dict[programExerciseId.uuidString] = now.addingTimeInterval(Self.snoozeDuration)
        save(dict)
    }

    private var snoozedUntil: [String: Date] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func save(_ dict: [String: Date]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        userDefaults.set(data, forKey: key)
    }
}
