import Foundation
import Supabase

@MainActor
final class ProgramRepository {
    private let client = SupabaseClientManager.shared.client

    func fetchAll() async throws -> [Program] {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw AppError.auth(.sessionMissing)
        }
        do {
            let programs: [Program] = try await client
                .from("programs")
                .select()
                .eq("user_id", value: userId)
                .order("updated_at", ascending: false)
                .execute()
                .value
            return programs
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "fetchPrograms", table: "programs"))
        }
    }

    func fetchFull(id: UUID) async throws -> Program {
        do {
            var program: Program = try await client
                .from("programs")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value

            let days: [ProgramDay] = try await client
                .from("program_days")
                .select()
                .eq("program_id", value: id)
                .order("day_order")
                .execute()
                .value

            let dayIds = days.map { $0.id }
            let exercises: [ProgramExercise] = try await client
                .from("program_exercises")
                .select()
                .in("program_day_id", values: dayIds)
                .order("exercise_order")
                .execute()
                .value

            program.days = days.map { day in
                var d = day
                d.exercises = exercises.filter { $0.programDayId == day.id }
                return d
            }
            return program
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "fetchFullProgram", table: "programs"))
        }
    }

    func fetchActive() async throws -> Program? {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw AppError.auth(.sessionMissing)
        }
        do {
            let programs: [Program] = try await client
                .from("programs")
                .select()
                .eq("user_id", value: userId)
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value
            guard let program = programs.first else { return nil }
            return try await fetchFull(id: program.id)
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "fetchActiveProgram", table: "programs"))
        }
    }

    func create(_ program: Program) async throws -> Program {
        do {
            let inserted: Program = try await client
                .from("programs")
                .insert(program)
                .select()
                .single()
                .execute()
                .value
            return inserted
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "createProgram", table: "programs"))
        }
    }

    func update(_ program: Program) async throws {
        do {
            try await client
                .from("programs")
                .update(program)
                .eq("id", value: program.id)
                .execute()
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "updateProgram", table: "programs"))
        }
    }

    func delete(id: UUID) async throws {
        do {
            try await client
                .from("programs")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "deleteProgram", table: "programs"))
        }
    }

    func setActive(programId: UUID) async throws {
        do {
            try await client
                .from("programs")
                .update(["is_active": true])
                .eq("id", value: programId)
                .execute()
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "setActiveProgram", table: "programs"))
        }
    }
}
