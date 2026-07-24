import SwiftUI

struct SubstituteCandidateSheet: View {
    let prompt: SubstitutePrompt
    var onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @State private var showingBrowseAll = false

    var body: some View {
        NavigationStack {
            Group {
                if prompt.candidates.isEmpty {
                    ContentUnavailableView("workout.substitute.sheet.empty", systemImage: "figure.strengthtraining.traditional")
                } else {
                    List {
                        ForEach(prompt.candidates) { candidate in
                            candidateRow(candidate)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelect(candidate.exercise)
                                    dismiss()
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if prompt.showsBrowseAllFallback {
                    Button {
                        showingBrowseAll = true
                    } label: {
                        Text("workout.substitute.sheet.browseAll")
                            .font(.system(.subheadline, design: .rounded).bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.bordered)
                    .padding()
                    .background(.bar)
                }
            }
            .navigationTitle("workout.substitute.sheet.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", role: .cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingBrowseAll) {
            ExercisePickerView(viewModel: ExercisePickerViewModel()) { exercise in
                onSelect(exercise)
                dismiss()
            }
        }
    }

    private func candidateRow(_ candidate: SubstituteCandidate) -> some View {
        HStack(spacing: 12) {
            EquipmentIconView(equipment: candidate.exercise.equipment)

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.exercise.name)
                    .font(.headline)

                HStack {
                    Text(candidate.exercise.equipment.localizedTitleKey)
                    if let lastLoggedWeightKg = candidate.lastLoggedWeightKg {
                        Text(verbatim: "•")
                        Text(String(format: String(localized: "workout.substitute.sheet.lastWeight"), weightText(lastLoggedWeightKg)))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func weightText(_ kilograms: Double) -> String {
        "\(appPreferences.weightUnit.formattedKilograms(kilograms, fractionLength: 0...2)) \(appPreferences.weightUnit.localizedAbbreviation)"
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            SubstituteCandidateSheet(
                prompt: SubstitutePrompt(
                    programExerciseId: UUID(),
                    originalExercise: ProgramSamples.benchPress,
                    candidates: [
                        SubstituteCandidate(exercise: ProgramSamples.machineChestPress, lastLoggedWeightKg: 40)
                    ],
                    showsBrowseAllFallback: true
                ),
                onSelect: { _ in }
            )
        }
        .environment(AppPreferences())
}
