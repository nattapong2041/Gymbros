import ActivityKit
import SwiftUI
import WidgetKit

struct RestTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerActivityAttributes.self) { context in
            RestTimerLockScreenView(context: context)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.primary)
                .widgetURL(context.attributes.deepLinkURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if isReady(context) {
                        Label("live_activity.ready", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                    } else {
                        Label("live_activity.rest", systemImage: "timer")
                            .font(.caption)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    statusText(context)
                        .font(.headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if isReady(context) {
                        Text("live_activity.ready_message")
                            .font(.caption)
                            .lineLimit(1)
                    } else {
                        Text(verbatim: context.attributes.exerciseName)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: isReady(context) ? "checkmark.circle.fill" : "timer")
            } compactTrailing: {
                compactStatusText(context)
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: isReady(context) ? "checkmark.circle.fill" : "timer")
            }
            .widgetURL(context.attributes.deepLinkURL)
        }
    }

    private func statusText(_ context: ActivityViewContext<RestTimerActivityAttributes>) -> Text {
        if isReady(context) {
            Text("live_activity.ready")
        } else {
            Text(context.state.endsAt, style: .timer)
        }
    }

    private func compactStatusText(_ context: ActivityViewContext<RestTimerActivityAttributes>) -> Text {
        if isReady(context) {
            Text("live_activity.ready_short")
        } else {
            Text(context.state.endsAt, style: .timer)
        }
    }

    private func isReady(_ context: ActivityViewContext<RestTimerActivityAttributes>) -> Bool {
        context.state.isComplete || context.isStale || context.state.endsAt <= Date()
    }
}

private struct RestTimerLockScreenView: View {
    let context: ActivityViewContext<RestTimerActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "timer")
                .font(.title3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                if isReady {
                    Text("live_activity.ready")
                        .font(.headline)
                    Text("live_activity.ready_message")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("live_activity.rest")
                        .font(.headline)
                    Text(verbatim: context.attributes.exerciseName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            if isReady {
                Text("live_activity.ready_short")
                    .font(.title3.monospacedDigit().bold())
            } else {
                Text(context.state.endsAt, style: .timer)
                    .font(.title3.monospacedDigit().bold())
            }
        }
        .padding()
    }

    private var isReady: Bool {
        context.state.isComplete || context.isStale || context.state.endsAt <= Date()
    }
}

@main
struct GymbrosWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivityWidget()
    }
}
