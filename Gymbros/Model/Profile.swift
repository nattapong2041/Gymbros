import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var email: String?
    var name: String?
    var experienceLevel: ExperienceLevel?
    var goal: Goal?
    var daysPerWeek: Int?
    var weightUnit: WeightUnit
    var locale: String
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email, name, goal, locale
        case experienceLevel = "experience_level"
        case daysPerWeek = "days_per_week"
        case weightUnit = "weight_unit"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
