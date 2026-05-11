import Foundation
import Supabase

@MainActor
protocol ProgramRepositoryProviding {
    func fetchAll() async throws -> [Program]
    func fetchFull(id: UUID) async throws -> Program
    func fetchDay(id: UUID) async throws -> ProgramDay
    func fetchProgramExercises(dayId: UUID) async throws -> [ProgramExercise]
    func fetchActive() async throws -> Program?
    func createProgram(name: String, description: String?) async throws -> Program
    func updateProgramMetadata(id: UUID, name: String, description: String?) async throws -> Program
    func delete(id: UUID) async throws
    func setActive(programId: UUID) async throws
    func createDay(programId: UUID, name: String, order: Int) async throws -> ProgramDay
    func updateDay(id: UUID, name: String, order: Int) async throws -> ProgramDay
    func deleteDay(id: UUID) async throws
    func reorderDays(_ days: [ProgramDay]) async throws
    func createProgramExercise(
        dayId: UUID,
        exerciseId: UUID,
        targetSets: Int,
        targetRepsMin: Int,
        targetRepsMax: Int,
        targetRestSeconds: Int,
        targetWeight: Double?,
        order: Int,
        notes: String?
    ) async throws -> ProgramExercise
    func updateProgramExercise(_ programExercise: ProgramExercise) async throws -> ProgramExercise
    func deleteProgramExercise(id: UUID) async throws
    func reorderProgramExercises(_ exercises: [ProgramExercise]) async throws
}

@MainActor
final class ProgramRepository: ProgramRepositoryProviding {
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

            let programIds = programs.map(\.id)
            guard !programIds.isEmpty else { return [] }

            let days: [ProgramDay] = try await client
                .from("program_days")
                .select()
                .in("program_id", values: programIds)
                .order("day_order")
                .execute()
                .value

            return Self.attachDays(days, to: programs)
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "fetchPrograms", table: "programs"))
        }
    }

    static func attachDays(_ days: [ProgramDay], to programs: [Program]) -> [Program] {
        let daysByProgramId = Dictionary(grouping: days, by: \.programId)
        return programs.map { program in
            var hydratedProgram = program
            hydratedProgram.days = ProgramOrderNormalizer.normalizeDays(daysByProgramId[program.id] ?? [])
            return hydratedProgram
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
            let exercises: [ProgramExercise]
            if dayIds.isEmpty {
                exercises = []
            } else {
                exercises = try await client
                    .from("program_exercises")
                    .select()
                    .in("program_day_id", values: dayIds)
                    .order("exercise_order")
                    .execute()
                    .value
            }

            program.days = ProgramOrderNormalizer.normalizeDays(days).map { day in
                var d = day
                d.exercises = ProgramOrderNormalizer.normalizeProgramExercises(exercises.filter { $0.programDayId == day.id })
                return d
            }
            return program
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "fetchFullProgram", table: "programs"))
        }
    }

    func fetchDay(id: UUID) async throws -> ProgramDay {
        do {
            let day: ProgramDay = try await client
                .from("program_days")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
            return day
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "fetchProgramDay", table: "program_days"))
        }
    }

    func fetchProgramExercises(dayId: UUID) async throws -> [ProgramExercise] {
        do {
            let exercises: [ProgramExercise] = try await client
                .from("program_exercises")
                .select()
                .eq("program_day_id", value: dayId)
                .order("exercise_order")
                .execute()
                .value
            return ProgramOrderNormalizer.normalizeProgramExercises(exercises)
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "fetchProgramExercises", table: "program_exercises"))
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
        try await createProgram(name: program.name, description: program.description)
    }

    func createProgram(name: String, description: String?) async throws -> Program {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw AppError.auth(.sessionMissing)
        }
        do {
            let inserted: Program = try await client
                .from("programs")
                .insert(ProgramInsertPayload(userId: userId, name: name, description: description))
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
        _ = try await updateProgramMetadata(id: program.id, name: program.name, description: program.description)
    }

    func updateProgramMetadata(id: UUID, name: String, description: String?) async throws -> Program {
        do {
            let updated: Program = try await client
                .from("programs")
                .update(ProgramUpdatePayload(name: name, description: description))
                .eq("id", value: id)
                .select()
                .single()
                .execute()
                .value
            return updated
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

    func createDay(programId: UUID, name: String, order: Int) async throws -> ProgramDay {
        do {
            let inserted: ProgramDay = try await client
                .from("program_days")
                .insert(ProgramDayInsertPayload(programId: programId, name: name, dayOrder: order))
                .select()
                .single()
                .execute()
                .value
            return inserted
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "createProgramDay", table: "program_days"))
        }
    }

    func updateDay(id: UUID, name: String, order: Int) async throws -> ProgramDay {
        do {
            let updated: ProgramDay = try await client
                .from("program_days")
                .update(ProgramDayUpdatePayload(name: name, dayOrder: order))
                .eq("id", value: id)
                .select()
                .single()
                .execute()
                .value
            return updated
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "updateProgramDay", table: "program_days"))
        }
    }

    func deleteDay(id: UUID) async throws {
        do {
            try await client
                .from("program_days")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "deleteProgramDay", table: "program_days"))
        }
    }

    func reorderDays(_ days: [ProgramDay]) async throws {
        do {
            for day in ProgramOrderNormalizer.normalizeDays(days) {
                try await client
                    .from("program_days")
                    .update(ProgramDayOrderPayload(dayOrder: day.dayOrder))
                    .eq("id", value: day.id)
                    .execute()
            }
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "reorderProgramDays", table: "program_days"))
        }
    }

    func createProgramExercise(
        dayId: UUID,
        exerciseId: UUID,
        targetSets: Int,
        targetRepsMin: Int,
        targetRepsMax: Int,
        targetRestSeconds: Int,
        targetWeight: Double?,
        order: Int,
        notes: String?
    ) async throws -> ProgramExercise {
        do {
            let inserted: ProgramExercise = try await client
                .from("program_exercises")
                .insert(ProgramExerciseInsertPayload(
                    programDayId: dayId,
                    exerciseId: exerciseId,
                    targetSets: targetSets,
                    targetRepsMin: targetRepsMin,
                    targetRepsMax: targetRepsMax,
                    targetRestSeconds: targetRestSeconds,
                    targetWeight: targetWeight,
                    exerciseOrder: order,
                    notes: notes
                ))
                .select()
                .single()
                .execute()
                .value
            return inserted
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "createProgramExercise", table: "program_exercises"))
        }
    }

    func updateProgramExercise(_ programExercise: ProgramExercise) async throws -> ProgramExercise {
        do {
            let updated: ProgramExercise = try await client
                .from("program_exercises")
                .update(ProgramExerciseUpdatePayload(programExercise: programExercise))
                .eq("id", value: programExercise.id)
                .select()
                .single()
                .execute()
                .value
            return updated
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "updateProgramExercise", table: "program_exercises"))
        }
    }

    func deleteProgramExercise(id: UUID) async throws {
        do {
            try await client
                .from("program_exercises")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "deleteProgramExercise", table: "program_exercises"))
        }
    }

    func reorderProgramExercises(_ exercises: [ProgramExercise]) async throws {
        do {
            for programExercise in ProgramOrderNormalizer.normalizeProgramExercises(exercises) {
                try await client
                    .from("program_exercises")
                    .update(ProgramExerciseOrderPayload(exerciseOrder: programExercise.exerciseOrder))
                    .eq("id", value: programExercise.id)
                    .execute()
            }
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "reorderProgramExercises", table: "program_exercises"))
        }
    }
}

struct ProgramInsertPayload: Encodable {
    let userId: UUID
    let name: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case description
    }
}

struct ProgramUpdatePayload: Encodable {
    let name: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        if let description {
            try container.encode(description, forKey: .description)
        } else {
            try container.encodeNil(forKey: .description)
        }
    }
}

struct ProgramDayInsertPayload: Encodable {
    let programId: UUID
    let name: String
    let dayOrder: Int

    enum CodingKeys: String, CodingKey {
        case programId = "program_id"
        case name
        case dayOrder = "day_order"
    }
}

struct ProgramDayUpdatePayload: Encodable {
    let name: String
    let dayOrder: Int

    enum CodingKeys: String, CodingKey {
        case name
        case dayOrder = "day_order"
    }
}

struct ProgramDayOrderPayload: Encodable {
    let dayOrder: Int

    enum CodingKeys: String, CodingKey {
        case dayOrder = "day_order"
    }
}

struct ProgramExerciseInsertPayload: Encodable {
    let programDayId: UUID
    let exerciseId: UUID
    let targetSets: Int
    let targetRepsMin: Int
    let targetRepsMax: Int
    let targetRestSeconds: Int
    let targetWeight: Double?
    let exerciseOrder: Int
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case programDayId = "program_day_id"
        case exerciseId = "exercise_id"
        case targetSets = "target_sets"
        case targetRepsMin = "target_reps_min"
        case targetRepsMax = "target_reps_max"
        case targetRestSeconds = "target_rest_seconds"
        case targetWeight = "target_weight"
        case exerciseOrder = "exercise_order"
        case notes
    }
}

struct ProgramExerciseUpdatePayload: Encodable {
    let targetSets: Int
    let targetRepsMin: Int
    let targetRepsMax: Int
    let targetRestSeconds: Int
    let targetWeight: Double?
    let exerciseOrder: Int
    let notes: String?

    init(programExercise: ProgramExercise) {
        self.targetSets = programExercise.targetSets
        self.targetRepsMin = programExercise.targetRepsMin
        self.targetRepsMax = programExercise.targetRepsMax
        self.targetRestSeconds = programExercise.targetRestSeconds
        self.targetWeight = programExercise.targetWeight
        self.exerciseOrder = programExercise.exerciseOrder
        self.notes = programExercise.notes
    }

    enum CodingKeys: String, CodingKey {
        case targetSets = "target_sets"
        case targetRepsMin = "target_reps_min"
        case targetRepsMax = "target_reps_max"
        case targetRestSeconds = "target_rest_seconds"
        case targetWeight = "target_weight"
        case exerciseOrder = "exercise_order"
        case notes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(targetSets, forKey: .targetSets)
        try container.encode(targetRepsMin, forKey: .targetRepsMin)
        try container.encode(targetRepsMax, forKey: .targetRepsMax)
        try container.encode(targetRestSeconds, forKey: .targetRestSeconds)
        if let targetWeight {
            try container.encode(targetWeight, forKey: .targetWeight)
        } else {
            try container.encodeNil(forKey: .targetWeight)
        }
        try container.encode(exerciseOrder, forKey: .exerciseOrder)
        if let notes {
            try container.encode(notes, forKey: .notes)
        } else {
            try container.encodeNil(forKey: .notes)
        }
    }
}

struct ProgramExerciseOrderPayload: Encodable {
    let exerciseOrder: Int

    enum CodingKeys: String, CodingKey {
        case exerciseOrder = "exercise_order"
    }
}
