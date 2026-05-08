import Foundation

struct Program: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    var name: String
    var description: String?
    var isActive: Bool
    let createdAt: Date
    var updatedAt: Date

    var days: [ProgramDay] = []

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case userId = "user_id"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
