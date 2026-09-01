import Foundation
import Testing
@testable import Gymbros

@Suite("AuthProvider")
struct AuthProviderTests {
    @Test func rawValuesAreStable() {
        // These strings are persisted by LastUsedAuthProviderStore and compared
        // against Supabase's provider names — they must not drift.
        #expect(AuthProvider.apple.rawValue == "apple")
        #expect(AuthProvider.google.rawValue == "google")
    }

    @Test func allCasesCoversExactlyAppleAndGoogle() {
        #expect(Set(AuthProvider.allCases) == [.apple, .google])
    }

    @Test func codableRoundTripsEveryCase() throws {
        for provider in AuthProvider.allCases {
            let data = try JSONEncoder().encode(provider)
            let decoded = try JSONDecoder().decode(AuthProvider.self, from: data)
            #expect(decoded == provider)
        }
    }

    @Test func decodesFromRawProviderString() throws {
        let decoded = try JSONDecoder().decode(AuthProvider.self, from: Data("\"google\"".utf8))
        #expect(decoded == .google)
    }
}
