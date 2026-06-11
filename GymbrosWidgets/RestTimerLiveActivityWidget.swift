import ActivityKit
import SwiftUI
import WidgetKit

struct RestTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerActivityAttributes.self) { context in
            RestTimerLockScreenView(context: context)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.primary)
                .widgetURL(deepLinkURL(context))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(statusTitle(context), systemImage: statusIcon(context))
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    statusText(context)
                        .font(.headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: context.state.workoutName)
                            .font(.caption)
                            .lineLimit(1)
                        bottomText(context)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: statusIcon(context))
            } compactTrailing: {
                compactStatusText(context)
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: compactTrailingWidth(context))
            } minimal: {
                Image(systemName: statusIcon(context))
            }
            .widgetURL(deepLinkURL(context))
        }
    }

    private func statusText(_ context: ActivityViewContext<RestTimerActivityAttributes>) -> Text {
        switch effectivePhase(context) {
        case .resting:
            if let restEndsAt = context.state.restEndsAt {
                Text(restEndsAt, style: .timer)
            } else {
                Text("live_activity.rest")
            }
        case .ready:
            Text("live_activity.ready")
        case .active:
            Text(context.state.workoutStartedAt, style: .timer)
        }
    }

    private func compactStatusText(_ context: ActivityViewContext<RestTimerActivityAttributes>) -> Text {
        switch effectivePhase(context) {
        case .resting:
            if let restEndsAt = context.state.restEndsAt {
                Text(restEndsAt, style: .timer)
            } else {
                Text("live_activity.rest_short")
            }
        case .ready:
            Text("live_activity.ready_short")
        case .active:
            Text(context.state.workoutStartedAt, style: .timer)
        }
    }

    private func bottomText(_ context: ActivityViewContext<RestTimerActivityAttributes>) -> Text {
        switch effectivePhase(context) {
        case .active:
            if let currentWork = context.state.currentWork {
                Text(verbatim: prescriptionSummary(currentWork))
            } else {
                Text("live_activity.workout")
            }
        case .resting:
            if let nextWork = context.state.nextWork {
                Text(verbatim: prescriptionSummary(nextWork))
            } else {
                Text("live_activity.rest")
            }
        case .ready:
            if let nextWork = context.state.nextWork {
                Text(verbatim: prescriptionSummary(nextWork))
            } else {
                Text("live_activity.ready_message")
            }
        }
    }

    private func statusTitle(_ context: ActivityViewContext<RestTimerActivityAttributes>) -> LocalizedStringKey {
        switch effectivePhase(context) {
        case .active:
            "live_activity.workout"
        case .resting:
            "live_activity.rest"
        case .ready:
            "live_activity.ready"
        }
    }

    private func statusIcon(_ context: ActivityViewContext<RestTimerActivityAttributes>) -> String {
        switch effectivePhase(context) {
        case .active:
            "figure.strengthtraining.traditional"
        case .resting:
            "timer"
        case .ready:
            "bolt.circle.fill"
        }
    }

    private func effectivePhase(
        _ context: ActivityViewContext<RestTimerActivityAttributes>
    ) -> RestTimerActivityAttributes.Phase {
        if context.state.phase == .resting,
           let restEndsAt = context.state.restEndsAt,
           restEndsAt <= Date() {
            return .ready
        }
        return context.state.phase
    }

    private func prescriptionSummary(_ work: RestTimerActivityAttributes.WorkState) -> String {
        if let weightText = work.weightText, weightText.isEmpty == false {
            return String(
                format: String(localized: "live_activity.prescription_summary.weighted"),
                weightText,
                work.setNumber,
                work.totalSets,
                work.repsText
            )
        }
        return String(
            format: String(localized: "live_activity.prescription_summary"),
            work.setNumber,
            work.totalSets,
            work.repsText
        )
    }

    private func compactTrailingWidth(_ context: ActivityViewContext<RestTimerActivityAttributes>) -> CGFloat {
        effectivePhase(context) == .ready ? 26 : 44
    }

    private func deepLinkURL(_ context: ActivityViewContext<RestTimerActivityAttributes>) -> URL? {
        context.attributes.deepLinkURL(programExerciseId: context.state.deepLinkProgramExerciseId)
    }
}

private struct RestTimerLockScreenView: View {
    let context: ActivityViewContext<RestTimerActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)

                Text(verbatim: context.state.workoutName)
                    .font(.subheadline)
                    .lineLimit(1)

                if let work = displayWork {
                    Text(verbatim: prescriptionSummary(work))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("live_activity.ready_message")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                if effectivePhase == .resting, let restEndsAt = context.state.restEndsAt {
                    Text(restEndsAt, style: .timer)
                        .font(.title3.monospacedDigit().bold())
                } else if effectivePhase == .ready {
                    Text("live_activity.ready_short")
                        .font(.title3.monospacedDigit().bold())
                } else {
                    Text(context.state.workoutStartedAt, style: .timer)
                        .font(.title3.monospacedDigit().bold())
                }

                if effectivePhase == .active {
                    Text("live_activity.elapsed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(context.state.workoutStartedAt, style: .timer)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    private var effectivePhase: RestTimerActivityAttributes.Phase {
        if context.state.phase == .resting,
           let restEndsAt = context.state.restEndsAt,
           restEndsAt <= Date() {
            return .ready
        }
        return context.state.phase
    }

    private var displayWork: RestTimerActivityAttributes.WorkState? {
        switch effectivePhase {
        case .active:
            context.state.currentWork
        case .resting, .ready:
            context.state.nextWork ?? context.state.currentWork
        }
    }

    private var statusTitle: LocalizedStringKey {
        switch effectivePhase {
        case .active:
            "live_activity.workout"
        case .resting:
            "live_activity.rest"
        case .ready:
            "live_activity.ready"
        }
    }

    private var statusIcon: String {
        switch effectivePhase {
        case .active:
            "figure.strengthtraining.traditional"
        case .resting:
            "timer"
        case .ready:
            "bolt.circle.fill"
        }
    }

    private func prescriptionSummary(_ work: RestTimerActivityAttributes.WorkState) -> String {
        if let weightText = work.weightText, weightText.isEmpty == false {
            return String(
                format: String(localized: "live_activity.prescription_summary.weighted"),
                weightText,
                work.setNumber,
                work.totalSets,
                work.repsText
            )
        }
        return String(
            format: String(localized: "live_activity.prescription_summary"),
            work.setNumber,
            work.totalSets,
            work.repsText
        )
    }
}

@main
struct GymbrosWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivityWidget()
    }
}
