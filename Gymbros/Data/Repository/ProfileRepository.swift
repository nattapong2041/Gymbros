import Foundation
import Supabase

@MainActor
final class ProfileRepository {
    private let client = SupabaseClientManager.shared.client

    func fetchCurrentProfile() async throws -> Profile {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw RepositoryError.notAuthenticated
        }
        let profile: Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return profile
    }

    func updateProfile(_ profile: Profile) async throws {
        try await client
            .from("profiles")
            .update(profile)
            .eq("id", value: profile.id)
            .execute()
    }
}
