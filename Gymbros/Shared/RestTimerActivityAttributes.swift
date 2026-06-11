import ActivityKit
import Foundation

struct RestTimerActivityAttributes: ActivityAttributes {
    enum Phase: String, Codable, Hashable {
        case active
        case resting
        case ready
    }

    struct WorkState: Codable, Hashable {
        var programExerciseId: UUID?
        var exerciseName: String
        var weightText: String?
        var setNumber: Int
        var totalSets: Int
        var repsText: String
    }

    struct ContentState: Codable, Hashable {
        var phase: Phase
        var workoutName: String
        var workoutStartedAt: Date
        var currentWork: WorkState?
        var nextWork: WorkState?
        var restStartedAt: Date?
        var restEndsAt: Date?

        var displayWork: WorkState? {
            nextWork ?? currentWork
        }

        var deepLinkProgramExerciseId: UUID? {
            displayWork?.programExerciseId
        }
    }

    var sessionId: UUID
    var programDayId: UUID?

    func deepLinkURL(programExerciseId: UUID?) -> URL? {
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
