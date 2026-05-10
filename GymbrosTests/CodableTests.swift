import Testing
import Foundation
@testable import Gymbros

@Suite("Codable Tests")
struct CodableTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    @Test func exerciseDecodesFromSupabaseJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name_en": "Bench Press",
            "name_th": "เบนช์เพรส",
            "movement_pattern": "push",
            "primary_muscle": "chest",
            "secondary_muscles": ["shoulders", "triceps"],
            "equipment": "barbell",
            "is_compound": true,
            "created_at": "2026-05-08T10:00:00Z"
        }
        """.data(using: .utf8)!

        let exercise = try decoder.decode(Exercise.self, from: json)

        #expect(exercise.nameEn == "Bench Press")
        #expect(exercise.nameTh == "เบนช์เพรส")
        #expect(exercise.movementPattern == .push)
        #expect(exercise.primaryMuscle == .chest)
        #expect(exercise.secondaryMuscles == [.shoulders, .triceps])
        #expect(exercise.equipment == .barbell)
        #expect(exercise.isCompound == true)
    }

    @Test func profileDecodesEmailFromSupabaseJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440010",
            "email": "user@example.com",
            "name": "Test User",
            "experience_level": "beginner",
            "goal": "strength",
            "days_per_week": 3,
            "weight_unit": "kg",
            "locale": "th",
            "created_at": "2026-05-08T10:00:00Z",
            "updated_at": "2026-05-08T10:00:00Z"
        }
        """.data(using: .utf8)!

        let profile = try decoder.decode(Profile.self, from: json)

        #expect(profile.email == "user@example.com")
        #expect(profile.name == "Test User")
    }

    @Test func programEncodesWithSnakeCaseKeys() throws {
        let program = Program(
            id: UUID(),
            userId: UUID(),
            name: "My Program",
            description: "Test",
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        let data = try encoder.encode(program)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["user_id"] != nil)
        #expect(json["is_active"] != nil)
        #expect(json["created_at"] != nil)
        #expect(json["updated_at"] != nil)
        #expect(json["userId"] == nil)
        #expect(json["days"] == nil)   // not in CodingKeys — must not appear
    }

    @Test func workoutSessionIsCompleteFlag() {
        let incomplete = WorkoutSession(
            id: UUID(), userId: UUID(), programDayId: nil,
            startedAt: Date(), endedAt: nil, notes: nil, createdAt: Date()
        )
        let complete = WorkoutSession(
            id: UUID(), userId: UUID(), programDayId: nil,
            startedAt: Date(), endedAt: Date(), notes: nil, createdAt: Date()
        )

        #expect(incomplete.isComplete == false)
        #expect(complete.isComplete == true)
        #expect(complete.duration != nil)
    }

    @Test func workoutSetDecodesFromJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "session_id": "550e8400-e29b-41d4-a716-446655440002",
            "exercise_id": "550e8400-e29b-41d4-a716-446655440003",
            "set_number": 1,
            "weight": 80.0,
            "reps": 8,
            "rpe": 7.5,
            "completed_at": "2026-05-08T10:00:00Z"
        }
        """.data(using: .utf8)!

        let set = try decoder.decode(WorkoutSet.self, from: json)

        #expect(set.setNumber == 1)
        #expect(set.weight == 80.0)
        #expect(set.reps == 8)
        #expect(set.rpe == 7.5)
    }
}
