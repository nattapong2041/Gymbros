import SwiftUI

struct SessionSetRow: View {
    let workoutSet: WorkoutSet

    var body: some View {
        HStack(spacing: 12) {
            Text("\(workoutSet.setNumber)")
                .font(.system(.subheadline, design: .rounded).bold())
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(weightRepsText)
                    .font(.body.bold())

                if let rpeText {
                    Text(rpeText)
                        .font(.caption)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var weightRepsText: String {
        String(
            format: String(localized: "session.set.weight_reps"),
            formattedWeight,
            workoutSet.reps
        )
    }

    private var rpeText: String? {
        guard let rpe = workoutSet.rpe else { return nil }
        return String(
            format: String(localized: "session.set.rpe"),
            formattedRPE(rpe)
        )
    }

    private var formattedWeight: String {
        workoutSet.weight.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func formattedRPE(_ rpe: Double) -> String {
        rpe.formatted(.number.precision(.fractionLength(0...1)))
    }
}
