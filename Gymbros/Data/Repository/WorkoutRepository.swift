import Foundation
import Supabase

@MainActor
final class WorkoutRepository {
    private let client = SupabaseClientManager.shared.client

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

    func uploadSet(_ set: WorkoutSet) async throws {
        do {
            try await client
                .from("workout_sets")
                .insert(set)
                .execute()
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "uploadWorkoutSet", table: "workout_sets"))
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
