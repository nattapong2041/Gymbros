import Foundation
import Supabase

@MainActor
protocol ExerciseRepositoryProviding {
    func fetchAll() async throws -> [Exercise]
}

@MainActor
final class ExerciseRepository: ExerciseRepositoryProviding {
    private let client = SupabaseClientManager.shared.client

    func fetchAll() async throws -> [Exercise] {
        do {
            let exercises: [Exercise] = try await client
                .from("exercises")
                .select()
                .order("name")
                .execute()
                .value
            return exercises
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "fetchAllExercises", table: "exercises"))
        }
    }

    func fetch(byMuscle muscle: MuscleGroup) async throws -> [Exercise] {
        do {
            let exercises: [Exercise] = try await client
                .from("exercises")
                .select()
                .eq("primary_muscle", value: muscle.rawValue)
                .order("name")
                .execute()
                .value
            return exercises
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "fetchExercisesByMuscle", table: "exercises"))
        }
    }

    func fetch(byPattern pattern: MovementPattern) async throws -> [Exercise] {
        do {
            let exercises: [Exercise] = try await client
                .from("exercises")
                .select()
                .eq("movement_pattern", value: pattern.rawValue)
                .order("name")
                .execute()
                .value
            return exercises
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "fetchExercisesByPattern", table: "exercises"))
        }
    }
}
