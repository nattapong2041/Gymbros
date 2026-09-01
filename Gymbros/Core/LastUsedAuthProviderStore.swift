import Foundation

@MainActor
protocol LastUsedAuthProviderStoring {
    var lastUsed: AuthProvider? { get }
    func record(_ provider: AuthProvider)
}

/// Remembers which provider the user last signed in with, so the sign-in
/// screen can nudge them back to the same one.
///
/// This is a UX hint only. It is *not* a mitigation for the Apple Hide My Email
/// / Gmail duplicate-account problem — see
/// `docs/superpowers/specs/2026-08-31-google-sign-in-design.md`.
@MainActor
final class LastUsedAuthProviderStore: LastUsedAuthProviderStoring {
    private let userDefaults: UserDefaults
    private let key = "last_used_auth_provider"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var lastUsed: AuthProvider? {
        guard let raw = userDefaults.string(forKey: key) else { return nil }
        return AuthProvider(rawValue: raw)
    }

    func record(_ provider: AuthProvider) {
        userDefaults.set(provider.rawValue, forKey: key)
    }
}
