import Foundation

struct ProgramExercise: Codable, Identifiable, Equatable {
    let id: UUID
    let programDayId: UUID
    let exerciseId: UUID
    var targetSets: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var targetRestSeconds: Int
    var targetWeight: Double?
    var exerciseOrder: Int
    var notes: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, notes
        case programDayId = "program_day_id"
        case exerciseId = "exercise_id"
        case targetSets = "target_sets"
        case targetRepsMin = "target_reps_min"
        case targetRepsMax = "target_reps_max"
        case targetRestSeconds = "target_rest_seconds"
        case targetWeight = "target_weight"
        case exerciseOrder = "exercise_order"
        case createdAt = "created_at"
    }
}
