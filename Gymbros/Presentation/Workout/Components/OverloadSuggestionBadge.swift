import SwiftUI

struct OverloadSuggestionBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.circle.fill")
                .accessibilityHidden(true)
            Text("workout.overload.badge")
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.green.opacity(0.15)))
        .foregroundStyle(.green)
        .accessibilityLabel(Text("accessibility.workout.overload_badge"))
    }
}

#Preview {
    OverloadSuggestionBadge()
        .padding()
}
