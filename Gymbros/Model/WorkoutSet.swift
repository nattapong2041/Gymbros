import Foundation

struct WorkoutSet: Codable, Identifiable, Equatable {
    let id: UUID
    let sessionId: UUID
    let exerciseId: UUID
    var setNumber: Int
    var weight: Double
    var reps: Int
    var rpe: Double?
    var completedAt: Date
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, weight, reps, rpe, notes
        case sessionId = "session_id"
        case exerciseId = "exercise_id"
        case setNumber = "set_number"
        case completedAt = "completed_at"
    }
}
