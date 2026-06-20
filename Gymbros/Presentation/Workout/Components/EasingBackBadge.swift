import SwiftUI

struct EasingBackBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.uturn.backward")
                .accessibilityHidden(true)
            Text("workout.comeback.easing_back")
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
        .foregroundStyle(.secondary)
        .accessibilityLabel(Text("accessibility.workout.easing_back"))
    }
}

#Preview {
    EasingBackBadge()
        .padding()
}
