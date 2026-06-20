import Foundation
import Supabase

@MainActor
protocol WorkoutRepositoryProviding {
    func insertSession(_ session: WorkoutSession) async throws
    func uploadSet(_ set: WorkoutSet) async throws -> WorkoutSet
    func updateSet(_ set: WorkoutSet) async throws -> WorkoutSet
    func updateSets(ids: [UUID], rpe: Double) async throws
    func deleteSet(id: UUID) async throws
    func deleteSession(id: UUID) async throws
    func completeSession(_ sessionId: UUID, endedAt: Date) async throws
    func updateSessionEndedAt(sessionId: UUID, endedAt: Date) async throws -> WorkoutSession
    func fetchLastLoggedSet(exerciseId: UUID, before: Date) async throws -> WorkoutSet?
    func fetchHistory(limit: Int) async throws -> [WorkoutSession]
    func fetchSets(sessionId: UUID) async throws -> [WorkoutSet]
}

@MainActor
final class WorkoutRepository: WorkoutRepositoryProviding {
    private let client = SupabaseClientManager.shared.client

    func insertSession(_ session: WorkoutSession) async throws {
        do {
            try await client
                .from("workout_sessions")
                .insert(WorkoutSessionInsertPayload(
                    id: session.id,
                    userId: session.userId,
                    programDayId: session.programDayId,
                    startedAt: session.startedAt,
                    endedAt: session.endedAt
                ), returning: .minimal)
                .execute()
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "insertWorkoutSession", table: "workout_sessions"))
        }
    }

    func uploadSet(_ set: WorkoutSet) async throws -> WorkoutSet {
        do {
            let inserted: WorkoutSet = try await client
                .from("workout_sets")
                .insert(set)
                .select()
                .single()
                .execute()
                .value
            return inserted
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "uploadWorkoutSet", table: "workout_sets"))
        }
    }

    func updateSet(_ set: WorkoutSet) async throws -> WorkoutSet {
        do {
            let updated: WorkoutSet = try await client
                .from("workout_sets")
                .update(WorkoutSetUpdatePayload(set: set))
                .eq("id", value: set.id)
                .select()
                .single()
                .execute()
                .value
            return updated
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "updateWorkoutSet", table: "workout_sets"))
        }
    }

    func updateSets(ids: [UUID], rpe: Double) async throws {
        guard ids.isEmpty == false else { return }
        do {
            try await client
                .from("workout_sets")
                .update(WorkoutSetRPEPayload(rpe: rpe), returning: .minimal)
                .in("id", values: ids)
                .execute()
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "updateWorkoutSetsRPE", table: "workout_sets"))
        }
    }

    func deleteSet(id: UUID) async throws {
        do {
            try await client
                .from("workout_sets")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "deleteWorkoutSet", table: "workout_sets"))
        }
    }

    func deleteSession(id: UUID) async throws {
        do {
            try await client
                .from("workout_sessions")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "deleteWorkoutSession", table: "workout_sessions"))
        }
    }

    func completeSession(_ sessionId: UUID, endedAt: Date) async throws {
        do {
            try await client
                .from("workout_sessions")
                .update(
                    WorkoutSessionCompletionPayload(endedAt: endedAt),
                    returning: .minimal
                )
                .eq("id", value: sessionId)
                .execute()
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "completeWorkoutSession", table: "workout_sessions"))
        }
    }

    func updateSessionEndedAt(sessionId: UUID, endedAt: Date) async throws -> WorkoutSession {
        do {
            let updated: WorkoutSession = try await client
                .from("workout_sessions")
                .update(WorkoutSessionCompletionPayload(endedAt: endedAt))
                .eq("id", value: sessionId)
                .select()
                .single()
                .execute()
                .value
            return updated
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "updateWorkoutSessionEndedAt", table: "workout_sessions"))
        }
    }

    func fetchLastLoggedSet(exerciseId: UUID, before: Date) async throws -> WorkoutSet? {
        do {
            let sets: [WorkoutSet] = try await client
                .from("workout_sets")
                .select()
                .eq("exercise_id", value: exerciseId)
                .lt("completed_at", value: before.ISO8601Format())
                .order("completed_at", ascending: false)
                .limit(1)
                .execute()
                .value
            return sets.first
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "fetchLastLoggedWorkoutSet", table: "workout_sets"))
        }
    }

    func fetchHistory(limit: Int = 50) async throws -> [WorkoutSession] {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw AppError.auth(.sessionMissing)
        }
        do {
            let sessions: [WorkoutSession] = try await client
                .from("workout_sessions")
                .select()
                .eq("user_id", value: userId)
                .not("ended_at", operator: .is, value: AnyJSON.null)
                .order("started_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return sessions
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "fetchWorkoutHistory", table: "workout_sessions"))
        }
    }

    func fetchSets(sessionId: UUID) async throws -> [WorkoutSet] {
        do {
            let sets: [WorkoutSet] = try await client
                .from("workout_sets")
                .select()
                .eq("session_id", value: sessionId)
                .order("exercise_id", ascending: true)
                .order("set_number", ascending: true)
                .execute()
                .value
            return sets
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "fetchWorkoutSets", table: "workout_sets"))
        }
    }
}

struct WorkoutSessionInsertPayload: Encodable {
    let id: UUID
    let userId: UUID
    let programDayId: UUID?
    let startedAt: Date
    let endedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case programDayId = "program_day_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
}

struct WorkoutSessionCompletionPayload: Encodable {
    let endedAt: String

    init(endedAt: Date) {
        self.endedAt = endedAt.ISO8601Format()
    }

    enum CodingKeys: String, CodingKey {
        case endedAt = "ended_at"
    }
}

struct WorkoutSetRPEPayload: Encodable {
    let rpe: Double
}

struct WorkoutSetUpdatePayload: Encodable {
    let setNumber: Int
    let weight: Double
    let reps: Int
    let rpe: Double?
    let targetRestSeconds: Int?
    let actualRestSeconds: Int?
    let restStartedAt: Date?
    let restEndedAt: Date?
    let completedAt: Date
    let notes: String?

    init(set: WorkoutSet) {
        setNumber = set.setNumber
        weight = set.weight
        reps = set.reps
        rpe = set.rpe
        targetRestSeconds = set.targetRestSeconds
        actualRestSeconds = set.actualRestSeconds
        restStartedAt = set.restStartedAt
        restEndedAt = set.restEndedAt
        completedAt = set.completedAt
        notes = set.notes
    }

    enum CodingKeys: String, CodingKey {
        case weight, reps, rpe, notes
        case setNumber = "set_number"
        case targetRestSeconds = "target_rest_seconds"
        case actualRestSeconds = "actual_rest_seconds"
        case restStartedAt = "rest_started_at"
        case restEndedAt = "rest_ended_at"
        case completedAt = "completed_at"
    }
}
