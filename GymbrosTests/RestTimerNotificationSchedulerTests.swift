import Foundation
import Testing
import UserNotifications
@testable import Gymbros

@MainActor
@Suite("RestTimerNotificationScheduler")
struct RestTimerNotificationSchedulerTests {
    @Test func scheduleAddsRequest() async {
        let (scheduler, center, _) = makeScheduler()
        let sessionId = UUID()

        await scheduler.schedule(
            after: 60,
            sessionId: sessionId,
            programDayId: UUID(),
            programExerciseId: UUID()
        )

        #expect(center.requests.count == 1)
        #expect(center.requests[0].identifier == RestTimerNotificationScheduler.identifier(sessionId: sessionId))
        #expect(center.requests[0].content.sound != nil)
    }

    @Test func scheduleReplacesExistingRequestForSameSession() async {
        let (scheduler, center, _) = makeScheduler()
        let sessionId = UUID()

        await scheduler.schedule(after: 60, sessionId: sessionId, programDayId: nil, programExerciseId: nil)
        await scheduler.schedule(after: 90, sessionId: sessionId, programDayId: nil, programExerciseId: nil)

        #expect(center.removedIdentifiers.contains(RestTimerNotificationScheduler.identifier(sessionId: sessionId)))
        #expect(center.requests.count == 1)
    }

    @Test func cancelRemovesPendingRequest() async {
        let (scheduler, center, _) = makeScheduler()
        let sessionId = UUID()

        await scheduler.schedule(after: 60, sessionId: sessionId, programDayId: nil, programExerciseId: nil)
        scheduler.cancel(sessionId: sessionId)

        #expect(center.requests.isEmpty)
    }

    @Test func requestAuthorizationSetsAskedFlag() async {
        let (scheduler, center, defaults) = makeScheduler()

        await scheduler.requestAuthorizationIfNeeded()

        #expect(defaults.bool(forKey: "rest_timer_notification_asked"))
        #expect(center.authorizationOptions.contains(.alert))
        #expect(center.authorizationOptions.contains(.sound))
    }

    @Test func requestAuthorizationDoesNotAskTwice() async {
        let (scheduler, center, defaults) = makeScheduler()
        defaults.set(true, forKey: "rest_timer_notification_asked")

        await scheduler.requestAuthorizationIfNeeded()

        #expect(center.authorizationRequestCount == 0)
    }

    private func makeScheduler() -> (RestTimerNotificationScheduler, FakeNotificationCenter, UserDefaults) {
        let center = FakeNotificationCenter()
        let defaults = UserDefaults(suiteName: "RestTimerNotificationSchedulerTests.\(UUID().uuidString)")!
        let scheduler = RestTimerNotificationScheduler(center: center, userDefaults: defaults)
        return (scheduler, center, defaults)
    }
}

@MainActor
private final class FakeNotificationCenter: NotificationCenterProviding {
    var requests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var authorizationRequestCount = 0
    var authorizationOptions: UNAuthorizationOptions = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequestCount += 1
        authorizationOptions = options
        return true
    }

    func add(_ request: UNNotificationRequest) async throws {
        requests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        requests.removeAll { identifiers.contains($0.identifier) }
    }
}
