import SwiftUI

struct SubstituteOriginBadge: View {
    let originExerciseName: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.uturn.left")
                .accessibilityHidden(true)
            Text(String(format: String(localized: "workout.substitute.badge"), originExerciseName))
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
        .foregroundStyle(.secondary)
        .accessibilityLabel(Text(String(format: String(localized: "accessibility.workout.substitute_badge"), originExerciseName)))
    }
}

#Preview {
    SubstituteOriginBadge(originExerciseName: "Bench Press")
        .padding()
}
