import Foundation

struct ProgramDay: Codable, Identifiable, Equatable {
    let id: UUID
    let programId: UUID
    var name: String
    var dayOrder: Int
    let createdAt: Date

    var exercises: [ProgramExercise] = []

    enum CodingKeys: String, CodingKey {
        case id, name
        case programId = "program_id"
        case dayOrder = "day_order"
        case createdAt = "created_at"
    }
}
