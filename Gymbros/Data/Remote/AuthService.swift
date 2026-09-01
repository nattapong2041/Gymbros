import Foundation
import Supabase

@MainActor
@Observable
class AuthService {
    static let shared = AuthService()

    private let client = SupabaseClientManager.shared.client

    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
    private var authStateTask: Task<Void, Never>?

    init() {
        let client = self.client
        authStateTask = Task { [weak self, client] in
            for await (_, session) in client.auth.authStateChanges {
                self?.applyAuthSession(session)
            }
        }
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

    /// Exchanges a provider ID token for a Supabase session.
    ///
    /// - Parameters:
    ///   - nonce: the **raw** (un-hashed) nonce. Supabase hashes it and compares
    ///     against the `nonce` claim in the ID token. The provider was handed
    ///     `NonceGenerator.sha256(nonce)`.
    ///   - accessToken: required for Google (its ID token carries an `at_hash`
    ///     claim); nil for Apple.
    ///   - email / fullName: used only to backfill the profile row; the DB
    ///     trigger already seeds it from `auth.users`.
    func signIn(
        provider: AuthProvider,
        idToken: String,
        accessToken: String? = nil,
        nonce: String,
        email: String?,
        fullName: String?
    ) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: provider.supabaseProvider,
                idToken: idToken,
                accessToken: accessToken,
                nonce: nonce
            )
        )
        self.currentUser = session.user
        await syncProfile(user: session.user, fallbackEmail: email, fullName: fullName)
    }

    func signOut() async throws {
        try await client.auth.signOut(scope: .local)
    }

    private func applyAuthSession(_ session: Session?) {
        currentUser = session?.user
    }

    /// Backfills `profiles.email` (always) and `profiles.name` (only when still
    /// null, so a user-set name is never clobbered). The `on_auth_user_created`
    /// trigger already seeds both from `auth.users`; this covers Apple's
    /// private-relay case and providers whose metadata arrives after the trigger.
    private func syncProfile(user: User, fallbackEmail: String?, fullName: String?) async {
        let email = user.email ?? fallbackEmail

        do {
            if let email, email.isEmpty == false {
                try await client
                    .from("profiles")
                    .update(["email": email])
                    .eq("id", value: user.id)
                    .execute()
            }

            if let fullName, fullName.isEmpty == false {
                try await client
                    .from("profiles")
                    .update(["name": fullName])
                    .eq("id", value: user.id)
                    .is("name", value: nil)
                    .execute()
            }
        } catch {
            #if DEBUG
            let appError = ErrorMapper.map(error, context: .init(operation: "syncProfile", table: "profiles"))
            debugPrint("Profile sync failed: \(appError)")
            #endif
        }
    }
}

private extension AuthProvider {
    var supabaseProvider: OpenIDConnectCredentials.Provider {
        switch self {
        case .apple: .apple
        case .google: .google
        }
    }
}
