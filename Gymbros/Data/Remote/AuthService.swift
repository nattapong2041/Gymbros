import Foundation
import Supabase

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private let client = SupabaseClientManager.shared.client

    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }

    private init() {
        Task { await loadCurrentSession() }
    }

    func loadCurrentSession() async {
        do {
            let session = try await client.auth.session
            self.currentUser = session.user
        } catch {
            self.currentUser = nil
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        self.currentUser = session.user
    }

    func signOut() async throws {
        try await client.auth.signOut()
        self.currentUser = nil
    }
}
