import Foundation

struct WorkoutSet: Codable, Identifiable, Equatable {
    let id: UUID
    let sessionId: UUID
    let exerciseId: UUID
    let programExerciseId: UUID?
    var setNumber: Int
    var weight: Double
    var reps: Int
    var rpe: Double?
    var targetRestSeconds: Int?
    var actualRestSeconds: Int?
    var restStartedAt: Date?
    var restEndedAt: Date?
    var completedAt: Date
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, weight, reps, rpe, notes
        case sessionId = "session_id"
        case exerciseId = "exercise_id"
        case programExerciseId = "program_exercise_id"
        case setNumber = "set_number"
        case targetRestSeconds = "target_rest_seconds"
        case actualRestSeconds = "actual_rest_seconds"
        case restStartedAt = "rest_started_at"
        case restEndedAt = "rest_ended_at"
        case completedAt = "completed_at"
    }
}
