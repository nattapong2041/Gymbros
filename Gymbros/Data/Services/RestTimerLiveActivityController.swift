import ActivityKit
import Foundation

@MainActor
protocol RestTimerLiveActivityControlling: AnyObject {
    func start(
        sessionId: UUID,
        programDayId: UUID?,
        state: RestTimerActivityAttributes.ContentState
    ) async
    func update(_ state: RestTimerActivityAttributes.ContentState) async
    func end() async
}

@MainActor
final class RestTimerLiveActivityController: RestTimerLiveActivityControlling {
    private var activity: Activity<RestTimerActivityAttributes>?

    func start(
        sessionId: UUID,
        programDayId: UUID?,
        state: RestTimerActivityAttributes.ContentState
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        await end()

        let attributes = RestTimerActivityAttributes(
            sessionId: sessionId,
            programDayId: programDayId
        )
        let content = ActivityContent(
            state: Self.contentState(from: state),
            staleDate: state.restEndsAt
        )

        do {
            activity = try Activity.request(attributes: attributes, content: content)
        } catch {
            #if DEBUG
            debugPrint("Failed to start rest timer Live Activity: \(error)")
            #endif
        }
    }

    func update(_ state: RestTimerActivityAttributes.ContentState) async {
        guard let activity else { return }
        let content = ActivityContent(
            state: Self.contentState(from: state),
            staleDate: state.restEndsAt
        )
        await activity.update(content)
    }

    func end() async {
        let activities = Activity<RestTimerActivityAttributes>.activities
        guard activities.isEmpty == false || activity != nil else { return }

        if activities.isEmpty, let activity {
            await end(activity)
        } else {
            for activity in activities {
                await end(activity)
            }
        }
        self.activity = nil
    }

    private func end(_ activity: Activity<RestTimerActivityAttributes>) async {
        let content = ActivityContent(
            state: activity.content.state,
            staleDate: Date()
        )
        await activity.end(content, dismissalPolicy: .immediate)
    }

    private static func contentState(
        from state: RestTimerActivityAttributes.ContentState
    ) -> RestTimerActivityAttributes.ContentState {
        state
    }
}
