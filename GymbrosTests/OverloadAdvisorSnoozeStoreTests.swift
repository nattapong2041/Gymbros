import Testing
import Foundation
@testable import Gymbros

@MainActor
@Suite("OverloadAdvisorSnoozeStore")
struct OverloadAdvisorSnoozeStoreTests {
    @Test func neverSnoozedReturnsFalse() {
        let store = makeStore()
        #expect(store.isSnoozed(programExerciseId: UUID(), now: .now) == false)
    }

    @Test func snoozedWithin14DaysReturnsTrue() {
        let store = makeStore()
        let id = UUID()
        let now = Date.now
        store.snooze(programExerciseId: id, now: now)

        #expect(store.isSnoozed(programExerciseId: id, now: now.addingTimeInterval(5 * 24 * 3600)))
    }

    @Test func snoozed15DaysAgoReturnsFalse() {
        let store = makeStore()
        let id = UUID()
        let now = Date.now
        store.snooze(programExerciseId: id, now: now)

        #expect(store.isSnoozed(programExerciseId: id, now: now.addingTimeInterval(15 * 24 * 3600)) == false)
    }

    @Test func persistsAcrossInstancesSharingUserDefaults() {
        let defaults = UserDefaults(suiteName: "OverloadAdvisorSnoozeStoreTests.\(UUID().uuidString)")!
        let id = UUID()
        let now = Date.now
        OverloadAdvisorSnoozeStore(userDefaults: defaults).snooze(programExerciseId: id, now: now)

        let reloaded = OverloadAdvisorSnoozeStore(userDefaults: defaults)
        #expect(reloaded.isSnoozed(programExerciseId: id, now: now.addingTimeInterval(24 * 3600)))
    }

    private func makeStore() -> OverloadAdvisorSnoozeStore {
        OverloadAdvisorSnoozeStore(userDefaults: UserDefaults(suiteName: "OverloadAdvisorSnoozeStoreTests.\(UUID().uuidString)")!)
    }
}
