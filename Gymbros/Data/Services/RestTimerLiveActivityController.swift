import ActivityKit
import Foundation

@MainActor
protocol RestTimerLiveActivityControlling: AnyObject {
    func start(
        state: RestTimerState,
        sessionId: UUID,
        programDayId: UUID?,
        programExerciseId: UUID?,
        exerciseName: String
    ) async
    func markComplete() async
    func end() async
}

@MainActor
final class RestTimerLiveActivityController: RestTimerLiveActivityControlling {
    private var activity: Activity<RestTimerActivityAttributes>?

    func start(
        state: RestTimerState,
        sessionId: UUID,
        programDayId: UUID?,
        programExerciseId: UUID?,
        exerciseName: String
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        await end()

        let attributes = RestTimerActivityAttributes(
            sessionId: sessionId,
            programDayId: programDayId,
            programExerciseId: programExerciseId,
            exerciseName: exerciseName
        )
        let content = ActivityContent(
            state: Self.contentState(from: state),
            staleDate: state.endsAt
        )

        do {
            activity = try Activity.request(attributes: attributes, content: content)
        } catch {
            #if DEBUG
            debugPrint("Failed to start rest timer Live Activity: \(error)")
            #endif
        }
    }

    func end() async {
        guard let activity else { return }
        let content = ActivityContent(
            state: activity.content.state,
            staleDate: Date()
        )
        await activity.end(content, dismissalPolicy: .immediate)
        self.activity = nil
    }

    func markComplete() async {
        guard let activity else { return }
        var state = activity.content.state
        state.isComplete = true
        state.remainingSeconds = 0
        let content = ActivityContent(
            state: state,
            staleDate: nil
        )
        await activity.update(content)
    }

    private static func contentState(from state: RestTimerState) -> RestTimerActivityAttributes.ContentState {
        RestTimerActivityAttributes.ContentState(
            startedAt: state.startedAt,
            endsAt: state.endsAt,
            remainingSeconds: state.remainingSeconds,
            isComplete: state.isComplete
        )
    }
}
