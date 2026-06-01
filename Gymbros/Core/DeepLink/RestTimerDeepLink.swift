import Foundation

struct WorkoutLaunchRoute: Identifiable, Hashable {
    var programDayId: UUID
    var programExerciseId: UUID?
    var sessionId: UUID?

    var id: String {
        [
            programDayId.uuidString,
            programExerciseId?.uuidString ?? "",
            sessionId?.uuidString ?? ""
        ].joined(separator: "-")
    }
}

enum RestTimerDeepLink {
    static let scheme = "gymbros"
    static let host = "workout"
    static let path = "/rest-timer"
    private static let urlKey = "gymbros_url"

    static func url(
        sessionId: UUID,
        programDayId: UUID?,
        programExerciseId: UUID?
    ) -> URL? {
        guard let programDayId else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path
        components.queryItems = [
            URLQueryItem(name: "sessionId", value: sessionId.uuidString),
            URLQueryItem(name: "programDayId", value: programDayId.uuidString),
            URLQueryItem(name: "programExerciseId", value: programExerciseId?.uuidString)
        ].compactMap { item in
            item.value == nil ? nil : item
        }
        return components.url
    }

    static func userInfo(
        sessionId: UUID,
        programDayId: UUID?,
        programExerciseId: UUID?
    ) -> [AnyHashable: Any] {
        guard let url = url(
            sessionId: sessionId,
            programDayId: programDayId,
            programExerciseId: programExerciseId
        ) else {
            return [:]
        }
        return [urlKey: url.absoluteString]
    }

    static func route(from url: URL) -> WorkoutLaunchRoute? {
        guard url.scheme == scheme,
              url.host == host,
              url.path == path,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let programDayIdString = components.queryItems?.first(where: { $0.name == "programDayId" })?.value,
              let programDayId = UUID(uuidString: programDayIdString) else {
            return nil
        }

        let programExerciseId = components.queryItems?
            .first(where: { $0.name == "programExerciseId" })?
            .value
            .flatMap(UUID.init(uuidString:))
        let sessionId = components.queryItems?
            .first(where: { $0.name == "sessionId" })?
            .value
            .flatMap(UUID.init(uuidString:))

        return WorkoutLaunchRoute(
            programDayId: programDayId,
            programExerciseId: programExerciseId,
            sessionId: sessionId
        )
    }

    static func route(from userInfo: [AnyHashable: Any]) -> WorkoutLaunchRoute? {
        guard let value = userInfo[urlKey] as? String,
              let url = URL(string: value) else {
            return nil
        }
        return route(from: url)
    }
}

@MainActor
@Observable
final class DeepLinkCoordinator {
    static let shared = DeepLinkCoordinator()

    var pendingWorkoutRoute: WorkoutLaunchRoute?

    func handle(_ url: URL) {
        guard let route = RestTimerDeepLink.route(from: url) else { return }
        pendingWorkoutRoute = route
    }

    func handleNotificationUserInfo(_ userInfo: [AnyHashable: Any]) {
        guard let route = RestTimerDeepLink.route(from: userInfo) else { return }
        pendingWorkoutRoute = route
    }
}
