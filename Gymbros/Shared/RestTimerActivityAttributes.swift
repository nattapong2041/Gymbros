import ActivityKit
import Foundation

struct RestTimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var endsAt: Date
        var remainingSeconds: Int
        var isComplete: Bool
    }

    var sessionId: UUID
    var programDayId: UUID?
    var programExerciseId: UUID?
    var exerciseName: String

    var deepLinkURL: URL? {
        guard let programDayId else { return nil }
        var components = URLComponents()
        components.scheme = "gymbros"
        components.host = "workout"
        components.path = "/rest-timer"
        components.queryItems = [
            URLQueryItem(name: "sessionId", value: sessionId.uuidString),
            URLQueryItem(name: "programDayId", value: programDayId.uuidString),
            URLQueryItem(name: "programExerciseId", value: programExerciseId?.uuidString)
        ].compactMap { $0.value == nil ? nil : $0 }
        return components.url
    }
}
