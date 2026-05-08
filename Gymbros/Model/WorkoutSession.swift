import Foundation

struct WorkoutSession: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    var programDayId: UUID?
    var startedAt: Date
    var endedAt: Date?
    var notes: String?
    let createdAt: Date

    var sets: [WorkoutSet] = []

    var isComplete: Bool { endedAt != nil }
    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    enum CodingKeys: String, CodingKey {
        case id, notes
        case userId = "user_id"
        case programDayId = "program_day_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case createdAt = "created_at"
    }
}
