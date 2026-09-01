import AuthenticationServices
import Foundation
import GoogleSignIn
import Observation

@MainActor
@Observable
final class SignInViewModel {
    var state: ViewState<Void> = .idle
    /// The provider whose sign-in is currently in flight. Drives per-button
    /// progress and disables both buttons while non-nil.
    private(set) var pendingProvider: AuthProvider?

    var lastUsedProvider: AuthProvider? { lastUsedStore.lastUsed }
    var isGoogleSignInAvailable: Bool { AppConstants.GoogleSignIn.isConfigured }

    private let auth: AuthService
    private let googleCredentialProvider: GoogleCredentialProviding
    private let lastUsedStore: LastUsedAuthProviderStoring

    /// Raw nonce for the in-flight Apple request. Google's raw nonce is a local
    /// in `signInWithGoogle()` and never needs to outlive the call.
    private var currentAppleNonce: String?
    /// Full name from the Apple credential — Apple delivers it only on the very
    /// first authorization, so it is captured in `prepareAppleSignIn` and read
    /// back in `handleAppleSignIn`.
    private var pendingAppleFullName: String?

    init(
        auth: AuthService = .shared,
        googleCredentialProvider: GoogleCredentialProviding? = nil,
        lastUsedStore: LastUsedAuthProviderStoring? = nil
    ) {
        self.auth = auth
        self.googleCredentialProvider = googleCredentialProvider ?? GoogleCredentialProvider()
        self.lastUsedStore = lastUsedStore ?? LastUsedAuthProviderStore()
    }

    // MARK: - Apple

    func prepareAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = NonceGenerator.randomNonceString()
        currentAppleNonce = nonce
        pendingAppleFullName = nil
        request.requestedScopes = [.fullName, .email]
        request.nonce = NonceGenerator.sha256(nonce)
        state = .idle
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            pendingProvider = .apple
            state = .loading
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = credential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8),
                  let nonce = currentAppleNonce else {
                pendingProvider = nil
                state = .error(.auth(.credentialMissing))
                return
            }

            let fullName = credential.fullName.flatMap(Self.formatted)

            do {
                try await auth.signIn(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce,
                    email: credential.email,
                    fullName: fullName
                )
                lastUsedStore.record(.apple)
                pendingProvider = nil
                state = .success(())
            } catch {
                pendingProvider = nil
                state = .error(ErrorMapper.map(error, context: .init(operation: "signInWithApple")))
            }
        case .failure(let error):
            pendingProvider = nil
            if Self.isUserCancellation(error) {
                state = .idle
            } else {
                state = .error(ErrorMapper.map(error, context: .init(operation: "appleAuthorization")))
            }
        }
    }

    // MARK: - Google

    func signInWithGoogle() async {
        guard pendingProvider == nil else { return }
        pendingProvider = .google
        state = .loading

        let rawNonce = NonceGenerator.randomNonceString()

        do {
            let credential = try await googleCredentialProvider.signIn(
                hashedNonce: NonceGenerator.sha256(rawNonce)
            )
            try await auth.signIn(
                provider: .google,
                idToken: credential.idToken,
                accessToken: credential.accessToken,
                nonce: rawNonce,
                email: credential.email,
                fullName: credential.fullName
            )
            lastUsedStore.record(.google)
            pendingProvider = nil
            state = .success(())
        } catch {
            pendingProvider = nil
            if Self.isUserCancellation(error) {
                state = .idle
            } else {
                state = .error(ErrorMapper.map(error, context: .init(operation: "signInWithGoogle")))
            }
        }
    }

    // MARK: - Helpers

    /// Covers both Apple (`ASAuthorizationError.canceled`) and Google
    /// (`GIDSignInError.canceled`) user-dismissal. Cancellation must never
    /// surface as an error.
    static func isUserCancellation(_ error: Error) -> Bool {
        if let appError = error as? AppError {
            return appError == .cancelled || appError == .auth(.signInCancelled)
        }
        if let gidError = error as? GIDSignInError {
            return gidError.code == .canceled
        }
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            return true
        }
        if nsError.domain == kGIDSignInErrorDomain,
           nsError.code == GIDSignInError.canceled.rawValue {
            return true
        }
        return false
    }

    private static func formatted(_ components: PersonNameComponents) -> String? {
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .long
        let name = formatter.string(from: components).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }
}
