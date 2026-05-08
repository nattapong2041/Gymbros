import Foundation
import Supabase

@MainActor
final class WorkoutRepository {
    private let client = SupabaseClientManager.shared.client

    func createSession(_ session: WorkoutSession) async throws -> WorkoutSession {
        let inserted: WorkoutSession = try await client
            .from("workout_sessions")
            .insert(session)
            .select()
            .single()
            .execute()
            .value
        return inserted
    }

    func uploadSet(_ set: WorkoutSet) async throws {
        try await client
            .from("workout_sets")
            .insert(set)
            .execute()
    }

    func completeSession(_ sessionId: UUID, endedAt: Date) async throws {
        try await client
            .from("workout_sessions")
            .update(["ended_at": endedAt.ISO8601Format()])
            .eq("id", value: sessionId)
            .execute()
    }

    func fetchHistory(limit: Int = 50) async throws -> [WorkoutSession] {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw RepositoryError.notAuthenticated
        }
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
    }
}
