import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    let id: UUID
    let ownerUserId: UUID?
    let slug: String?
    let name: String
    let movementPattern: MovementPattern
    let primaryMuscle: MuscleGroup
    let secondaryMuscles: [MuscleGroup]
    let equipment: Equipment
    let isCompound: Bool
    let createdAt: Date

    var displayName: String { name }

    enum CodingKeys: String, CodingKey {
        case id, slug, name, equipment
        case ownerUserId = "owner_user_id"
        case movementPattern = "movement_pattern"
        case primaryMuscle = "primary_muscle"
        case secondaryMuscles = "secondary_muscles"
        case isCompound = "is_compound"
        case createdAt = "created_at"
    }
}
