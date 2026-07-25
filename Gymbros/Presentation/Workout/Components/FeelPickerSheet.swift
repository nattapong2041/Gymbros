import SwiftUI

/// Shared effort-rating sheet used by both the live logger (SetRowView) and History's
/// edit-set form (SessionDetailView). Slide or tap the 1-10 track; the icon, band name,
/// and description above it update live to teach what each level means as you move.
struct FeelPickerSheet: View {
    @State private var draftValue: Int
    let onConfirm: (Double) -> Void
    let onClear: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(initialRPE: Double?, onConfirm: @escaping (Double) -> Void, onClear: @escaping () -> Void) {
        let initialInt = initialRPE.map { Int($0.rounded()) } ?? 5
        _draftValue = State(initialValue: min(max(initialInt, 1), 10))
        self.onConfirm = onConfirm
        self.onClear = onClear
    }

    private var currentBand: HowDidThatFeel {
        HowDidThatFeel.band(for: Double(draftValue))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Image(systemName: currentBand.symbolName)
                        .font(.system(size: 52))
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)

                    Text(LocalizedStringKey(currentBand.titleKey))
                        .font(.title.bold())

                    Text(LocalizedStringKey(currentBand.descriptionKey))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)
                .animation(.easeInOut(duration: 0.15), value: draftValue)

                Text(verbatim: "\(draftValue)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityHidden(true)

                EffortLevelTrack(value: $draftValue)
                    .frame(height: 88)
                    .padding(.horizontal)

                Button(role: .destructive) {
                    onClear()
                    dismiss()
                } label: {
                    Text("workout.set.feel.clear")
                }
                .frame(minHeight: 48)

                Spacer()
            }
            .padding()
            .navigationTitle("workout.set.feel.picker.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        onConfirm(Double(draftValue))
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#if DEBUG
#Preview("Unset") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            FeelPickerSheet(initialRPE: nil, onConfirm: { _ in }, onClear: {})
        }
}

#Preview("Set to Hard") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            FeelPickerSheet(initialRPE: 7, onConfirm: { _ in }, onClear: {})
        }
}
#endif
