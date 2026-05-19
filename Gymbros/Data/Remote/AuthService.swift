import Foundation
import Supabase

@MainActor
@Observable
class AuthService {
    static let shared = AuthService()

    private let client = SupabaseClientManager.shared.client

    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }

    init() {
        Task { await loadCurrentSession() }
    }

    func loadCurrentSession() async {
        if let cachedUser = client.auth.currentUser {
            self.currentUser = cachedUser
        }

        do {
            self.currentUser = try await client.auth.user()
        } catch {
            guard Self.shouldClearCurrentUser(afterSessionLoadFailure: error) else {
                #if DEBUG
                let appError = ErrorMapper.map(error, context: .init(operation: "loadCurrentSession"))
                debugPrint("Session refresh failed without clearing auth: \(appError)")
                #endif
                return
            }

            try? await client.auth.signOut(scope: .local)
            self.currentUser = nil
        }
    }

    nonisolated static func shouldClearCurrentUser(afterSessionLoadFailure error: Error) -> Bool {
        let appError = ErrorMapper.map(error, context: .init(operation: "loadCurrentSession"))
        switch appError {
        case .auth(.sessionMissing), .auth(.tokenExpired):
            return true
        default:
            return false
        }
    }

    func signInWithApple(idToken: String, nonce: String, email: String?) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        self.currentUser = session.user
        await syncProfileEmail(user: session.user, appleEmail: email)
    }

    func signOut() async throws {
        try await client.auth.signOut()
        self.currentUser = nil
    }

    private func syncProfileEmail(user: User, appleEmail: String?) async {
        let email = user.email ?? appleEmail
        guard let email, email.isEmpty == false else { return }

        do {
            try await client
                .from("profiles")
                .update(["email": email])
                .eq("id", value: user.id)
                .execute()
        } catch {
            #if DEBUG
            let appError = ErrorMapper.map(error, context: .init(operation: "syncProfileEmail", table: "profiles"))
            debugPrint("Profile email sync failed: \(appError)")
            #endif
        }
    }
}
