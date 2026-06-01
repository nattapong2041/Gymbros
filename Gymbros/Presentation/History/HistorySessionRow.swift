import SwiftUI

struct HistorySessionRow: View {
    let session: WorkoutSession
    let dayName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dayName ?? String(localized: "history.session.custom"))
                .font(.headline)

            Text(subheadline)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var subheadline: String {
        "\(session.startedAt.workoutDisplayString) • \(durationText)"
    }

    private var durationText: String {
        String(
            format: String(localized: "history.session.duration"),
            durationMinutes
        )
    }

    private var accessibilityLabel: String {
        String(
            format: String(localized: "accessibility.history.session_row"),
            dayName ?? String(localized: "history.session.custom"),
            durationMinutes
        )
    }

    private var durationMinutes: Int {
        guard let duration = session.duration else { return 0 }
        return max(1, Int((duration / 60).rounded()))
    }
}
