import Foundation
import Supabase

@MainActor
protocol WorkoutRepositoryProviding {
    func createSession(programDayId: UUID, startedAt: Date) async throws -> WorkoutSession
    func uploadSet(_ set: WorkoutSet) async throws -> WorkoutSet
    func updateSet(_ set: WorkoutSet) async throws -> WorkoutSet
    func deleteSet(id: UUID) async throws
    func completeSession(_ sessionId: UUID, endedAt: Date) async throws
    func fetchHistory(limit: Int) async throws -> [WorkoutSession]
}

@MainActor
final class WorkoutRepository: WorkoutRepositoryProviding {
    private let client = SupabaseClientManager.shared.client

    func createSession(programDayId: UUID, startedAt: Date) async throws -> WorkoutSession {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw AppError.auth(.sessionMissing)
        }
        do {
            let inserted: WorkoutSession = try await client
                .from("workout_sessions")
                .insert(WorkoutSessionInsertPayload(
                    userId: userId,
                    programDayId: programDayId,
                    startedAt: startedAt
                ))
                .select()
                .single()
                .execute()
                .value
            return inserted
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "createWorkoutSession", table: "workout_sessions"))
        }
    }

    func createSession(_ session: WorkoutSession) async throws -> WorkoutSession {
        do {
            let inserted: WorkoutSession = try await client
                .from("workout_sessions")
                .insert(session)
                .select()
                .single()
                .execute()
                .value
            return inserted
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "createWorkoutSession", table: "workout_sessions"))
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

    func completeSession(_ sessionId: UUID, endedAt: Date) async throws {
        do {
            try await client
                .from("workout_sessions")
                .update(["ended_at": endedAt.ISO8601Format()])
                .eq("id", value: sessionId)
                .execute()
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "completeWorkoutSession", table: "workout_sessions"))
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
}

struct WorkoutSessionInsertPayload: Encodable {
    let userId: UUID
    let programDayId: UUID
    let startedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case programDayId = "program_day_id"
        case startedAt = "started_at"
    }
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
