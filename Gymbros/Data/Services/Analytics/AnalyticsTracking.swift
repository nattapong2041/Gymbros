import Foundation
import OSLog

enum AnalyticsEvent {
    case comebackCardShown
    case comebackSessionStarted
    case comebackSessionFinished
    case comebackExitBaselineReached
    case exerciseSubstituted
    case substituteRankSelected
}

protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

struct NoopAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}

#if DEBUG
struct DebugConsoleAnalytics: AnalyticsTracking {
    private static let logger = Logger(subsystem: "com.nattapongsawa.gymbros", category: "Analytics")

    func track(_ event: AnalyticsEvent) {
        Self.logger.log("analytics: \(String(describing: event), privacy: .public)")
    }
}
#endif

enum AnalyticsProvider {
    static func makeDefault() -> AnalyticsTracking {
        #if DEBUG
        DebugConsoleAnalytics()
        #else
        NoopAnalytics()
        #endif
    }
}
