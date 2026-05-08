import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    let id: UUID
    let nameEn: String
    let nameTh: String
    let movementPattern: MovementPattern
    let primaryMuscle: MuscleGroup
    let secondaryMuscles: [MuscleGroup]
    let equipment: Equipment
    let isCompound: Bool
    let createdAt: Date

    var localizedName: String {
        Locale.current.language.languageCode?.identifier == "th" ? nameTh : nameEn
    }

    enum CodingKeys: String, CodingKey {
        case id, equipment
        case nameEn = "name_en"
        case nameTh = "name_th"
        case movementPattern = "movement_pattern"
        case primaryMuscle = "primary_muscle"
        case secondaryMuscles = "secondary_muscles"
        case isCompound = "is_compound"
        case createdAt = "created_at"
    }
}
