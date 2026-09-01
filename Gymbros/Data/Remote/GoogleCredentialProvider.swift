import Foundation
import GoogleSignIn
import UIKit

/// The tokens and profile fields GymBros needs from a Google sign-in.
struct GoogleCredential: Equatable, Sendable {
    let idToken: String
    let accessToken: String
    let email: String?
    let fullName: String?
}

enum GoogleCredentialError: Error, Equatable {
    /// Sign-in succeeded but no ID token came back — cannot exchange with Supabase.
    case missingIDToken
    /// No window/root view controller to present the Google sheet from.
    case noPresentingViewController
    /// `AppConstants.GoogleSignIn` still holds TODO placeholders.
    case notConfigured
}

@MainActor
protocol GoogleCredentialProviding: Sendable {
    /// Presents the native Google account sheet and returns the resulting credential.
    ///
    /// - Parameter hashedNonce: `NonceGenerator.sha256(rawNonce)` — Google embeds this
    ///   in the ID token's `nonce` claim, and Supabase compares it against
    ///   `sha256` of the raw nonce we pass to `signInWithIdToken`.
    /// - Throws: `GIDSignInError` (`.canceled` when the user dismisses the sheet),
    ///   or `GoogleCredentialError`.
    func signIn(hashedNonce: String) async throws -> GoogleCredential
}

@MainActor
final class GoogleCredentialProvider: GoogleCredentialProviding {
    /// Call once at launch before any sign-in. Also required before
    /// `GIDSignIn.sharedInstance.restorePreviousSignIn(...)`.
    static func configure() {
        guard AppConstants.GoogleSignIn.isConfigured else {
            #if DEBUG
            debugPrint("GoogleSignIn not configured — fill in AppConstants.GoogleSignIn client IDs.")
            #endif
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: AppConstants.GoogleSignIn.iosClientID,
            serverClientID: AppConstants.GoogleSignIn.webClientID
        )
    }

    func signIn(hashedNonce: String) async throws -> GoogleCredential {
        guard AppConstants.GoogleSignIn.isConfigured else {
            throw GoogleCredentialError.notConfigured
        }
        if GIDSignIn.sharedInstance.configuration == nil {
            Self.configure()
        }
        guard let presenter = UIApplication.shared.topViewController else {
            throw GoogleCredentialError.noPresentingViewController
        }

        let result: GIDSignInResult = try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: presenter,
                hint: nil,
                additionalScopes: nil,
                nonce: hashedNonce
            ) { signInResult, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let signInResult {
                    continuation.resume(returning: signInResult)
                } else {
                    continuation.resume(throwing: GoogleCredentialError.missingIDToken)
                }
            }
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleCredentialError.missingIDToken
        }

        return GoogleCredential(
            idToken: idToken,
            accessToken: result.user.accessToken.tokenString,
            email: result.user.profile?.email,
            fullName: result.user.profile?.name
        )
    }
}
