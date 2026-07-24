import Testing
import Foundation
@testable import Gymbros

@MainActor
@Suite("OverloadSuggestionTracker")
struct OverloadSuggestionTrackerTests {
    @Test func neverRecordedReturnsNil() {
        let tracker = makeTracker()
        #expect(tracker.pendingPreviousWeight(programExerciseId: UUID()) == nil)
    }

    @Test func recordedSuggestionReturnsPreviousWeight() {
        let tracker = makeTracker()
        let id = UUID()
        tracker.recordSuggestion(programExerciseId: id, previousWeight: 80)

        #expect(tracker.pendingPreviousWeight(programExerciseId: id) == 80)
    }

    @Test func clearingRemovesTheSuggestion() {
        let tracker = makeTracker()
        let id = UUID()
        tracker.recordSuggestion(programExerciseId: id, previousWeight: 80)
        tracker.clearSuggestion(programExerciseId: id)

        #expect(tracker.pendingPreviousWeight(programExerciseId: id) == nil)
    }

    @Test func recordingAgainOverwritesThePreviousValue() {
        let tracker = makeTracker()
        let id = UUID()
        tracker.recordSuggestion(programExerciseId: id, previousWeight: 80)
        tracker.recordSuggestion(programExerciseId: id, previousWeight: 82.5)

        #expect(tracker.pendingPreviousWeight(programExerciseId: id) == 82.5)
    }

    @Test func persistsAcrossInstancesSharingUserDefaults() {
        let defaults = UserDefaults(suiteName: "OverloadSuggestionTrackerTests.\(UUID().uuidString)")!
        let id = UUID()
        OverloadSuggestionTracker(userDefaults: defaults).recordSuggestion(programExerciseId: id, previousWeight: 80)

        let reloaded = OverloadSuggestionTracker(userDefaults: defaults)
        #expect(reloaded.pendingPreviousWeight(programExerciseId: id) == 80)
    }

    private func makeTracker() -> OverloadSuggestionTracker {
        OverloadSuggestionTracker(userDefaults: UserDefaults(suiteName: "OverloadSuggestionTrackerTests.\(UUID().uuidString)")!)
    }
}
