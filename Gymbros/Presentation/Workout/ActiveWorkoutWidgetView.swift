import SwiftUI

struct ActiveWorkoutWidgetView: View {
    let snapshot: ActiveSessionSnapshot
    let weightUnit: WeightUnit
    let onResume: (WorkoutLaunchRoute) -> Void
    let onStop: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let data = ActiveWorkoutWidgetData(
                snapshot: snapshot,
                weightUnit: weightUnit,
                date: context.date
            ) {
                HStack(spacing: 10) {
                    Button {
                        onResume(data.route)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 56, height: 56)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("active_workout.resume.accessibility_label"))

                    Button {
                        onResume(data.route)
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor(for: data.status))
                                .frame(width: 10, height: 10)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: data.compactStatusText)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text(verbatim: data.exerciseName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(data.accessibilityLabel))

                    Button {
                        onStop()
                    } label: {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundStyle(.red)
                            .frame(width: 56, height: 56)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("active_workout.stop.accessibility_label"))
                }
                .padding(10)
                .frame(minHeight: 78)
                .activeWorkoutWidgetBackground()
            }
        }
    }

    private func statusColor(for status: ActiveWorkoutWidgetData.Status) -> Color {
        switch status {
        case .working:
            .blue
        case .resting:
            .orange
        case .ready:
            .green
        }
    }
}

private extension View {
    @ViewBuilder
    func activeWorkoutWidgetBackground() -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular, in: .rect(cornerRadius: 39))
        } else {
            self
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 39, style: .continuous))
        }
    }
}
