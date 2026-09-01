import Foundation
import Testing
@testable import Gymbros

@MainActor
@Suite("LastUsedAuthProviderStore")
struct LastUsedAuthProviderStoreTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "test.lastUsedAuthProvider.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func defaultsToNil() {
        let store = LastUsedAuthProviderStore(userDefaults: makeDefaults())
        #expect(store.lastUsed == nil)
    }

    @Test func recordsAndReadsBack() {
        let defaults = makeDefaults()
        let store = LastUsedAuthProviderStore(userDefaults: defaults)

        store.record(.google)
        #expect(store.lastUsed == .google)

        store.record(.apple)
        #expect(store.lastUsed == .apple)
    }

    @Test func survivesAcrossInstances() {
        let defaults = makeDefaults()
        LastUsedAuthProviderStore(userDefaults: defaults).record(.google)

        let reopened = LastUsedAuthProviderStore(userDefaults: defaults)
        #expect(reopened.lastUsed == .google)
    }

    @Test func ignoresUnknownStoredValue() {
        let defaults = makeDefaults()
        defaults.set("myspace", forKey: "last_used_auth_provider")
        #expect(LastUsedAuthProviderStore(userDefaults: defaults).lastUsed == nil)
    }
}
