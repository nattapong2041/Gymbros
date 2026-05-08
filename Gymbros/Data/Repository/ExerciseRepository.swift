import Foundation
import Supabase

@MainActor
final class ExerciseRepository {
    private let client = SupabaseClientManager.shared.client

    func fetchAll() async throws -> [Exercise] {
        let exercises: [Exercise] = try await client
            .from("exercises")
            .select()
            .order("name_en")
            .execute()
            .value
        return exercises
    }

    func fetch(byMuscle muscle: MuscleGroup) async throws -> [Exercise] {
        let exercises: [Exercise] = try await client
            .from("exercises")
            .select()
            .eq("primary_muscle", value: muscle.rawValue)
            .order("name_en")
            .execute()
            .value
        return exercises
    }

    func fetch(byPattern pattern: MovementPattern) async throws -> [Exercise] {
        let exercises: [Exercise] = try await client
            .from("exercises")
            .select()
            .eq("movement_pattern", value: pattern.rawValue)
            .order("name_en")
            .execute()
            .value
        return exercises
    }
}
