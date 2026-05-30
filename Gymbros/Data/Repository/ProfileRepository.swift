import Foundation
import Supabase

protocol ProfileRepositoryProviding {
    func fetchCurrentProfile() async throws -> Profile
    func updateProfile(_ profile: Profile) async throws
}

@MainActor
final class ProfileRepository: ProfileRepositoryProviding {
    private let client = SupabaseClientManager.shared.client

    func fetchCurrentProfile() async throws -> Profile {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw AppError.auth(.sessionMissing)
        }
        do {
            let profile: Profile = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            return profile
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "fetchCurrentProfile", table: "profiles"))
        }
    }

    func updateProfile(_ profile: Profile) async throws {
        do {
            try await client
                .from("profiles")
                .update(profile)
                .eq("id", value: profile.id)
                .execute()
        } catch {
            throw ErrorMapper.map(error, context: .init(operation: "updateProfile", table: "profiles"))
        }
    }
}
