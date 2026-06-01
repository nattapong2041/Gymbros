import Foundation
import UserNotifications

@MainActor
protocol NotificationCenterProviding: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationCenterProviding {}

@MainActor
protocol RestTimerScheduling: AnyObject {
    func requestAuthorizationIfNeeded() async
    func schedule(
        after seconds: TimeInterval,
        sessionId: UUID,
        programDayId: UUID?,
        programExerciseId: UUID?
    ) async
    func cancel(sessionId: UUID)
    func cancelAll()
}

@MainActor
final class RestTimerNotificationScheduler: RestTimerScheduling {
    private let center: any NotificationCenterProviding
    private let userDefaults: UserDefaults
    private let askedKey = "rest_timer_notification_asked"
    private var scheduledIdentifiers: Set<String> = []

    init(
        center: (any NotificationCenterProviding)? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.center = center ?? UNUserNotificationCenter.current()
        self.userDefaults = userDefaults
    }

    func requestAuthorizationIfNeeded() async {
        guard userDefaults.bool(forKey: askedKey) == false else { return }
        userDefaults.set(true, forKey: askedKey)
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(
        after seconds: TimeInterval,
        sessionId: UUID,
        programDayId: UUID?,
        programExerciseId: UUID?
    ) async {
        let identifier = Self.identifier(sessionId: sessionId)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        scheduledIdentifiers.remove(identifier)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "workout.rest_timer.notification.title")
        content.body = String(localized: "workout.rest_timer.notification.body")
        content.sound = .default
        content.userInfo = RestTimerDeepLink.userInfo(
            sessionId: sessionId,
            programDayId: programDayId,
            programExerciseId: programExerciseId
        )

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(seconds, 1),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            scheduledIdentifiers.insert(identifier)
        } catch {
            #if DEBUG
            debugPrint("Failed to schedule rest timer notification: \(error)")
            #endif
        }
    }

    func cancel(sessionId: UUID) {
        let identifier = Self.identifier(sessionId: sessionId)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        scheduledIdentifiers.remove(identifier)
    }

    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: Array(scheduledIdentifiers))
        scheduledIdentifiers.removeAll()
    }

    static func identifier(sessionId: UUID) -> String {
        "rest-timer-\(sessionId.uuidString)"
    }
}
