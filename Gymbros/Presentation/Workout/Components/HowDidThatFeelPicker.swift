import SwiftUI

struct HowDidThatFeelPicker: View {
    /// `nil` means the user skipped — no RPE write.
    let onSelect: (HowDidThatFeel?) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("workout.comeback.feel.title")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(HowDidThatFeel.allCases, id: \.self) { feel in
                    feelButton(feel)
                }
            }
            .frame(minHeight: 48)

            Button("workout.comeback.feel.skip") {
                onSelect(nil)
            }
            .buttonStyle(.borderless)
            .frame(minHeight: 48)
        }
        .padding()
        .presentationDetents([.medium])
    }

    private func feelButton(_ feel: HowDidThatFeel) -> some View {
        Button {
            onSelect(feel)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: feel.symbolName)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(LocalizedStringKey(feel.titleKey))
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    HowDidThatFeelPicker(onSelect: { _ in })
}
