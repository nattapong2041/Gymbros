import SwiftUI

struct ExercisePickerView<VM: ExercisePickerProtocol>: View {
    @State var viewModel: VM
    var onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                filterSection

                if viewModel.filteredExercises.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    ForEach(viewModel.filteredExercises) { exercise in
                        ExercisePickerRow(exercise: exercise)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(exercise)
                                dismiss()
                            }
                    }
                }
            }
            .navigationTitle("exercisePicker.title")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "exercisePicker.search.prompt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("exercisePicker.clearFilters.action") {
                        viewModel.clearFilters()
                    }
                    .disabled(viewModel.selectedMuscle == nil && viewModel.selectedEquipment == nil && viewModel.selectedPattern == nil)
                }
            }
            .task {
                await viewModel.loadExercises()
            }
        }
    }

    private var filterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterMenu(
                        selection: $viewModel.selectedMuscle,
                        label: "exercisePicker.filter.muscle",
                        options: MuscleGroup.allCases,
                        keyPrefix: "muscleGroup"
                    )

                    filterMenu(
                        selection: $viewModel.selectedEquipment,
                        label: "exercisePicker.filter.equipment",
                        options: Equipment.allCases,
                        keyPrefix: "equipment"
                    )

                    filterMenu(
                        selection: $viewModel.selectedPattern,
                        label: "exercisePicker.filter.pattern",
                        options: MovementPattern.allCases,
                        keyPrefix: "movementPattern"
                    )
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("exercisePicker.filters.section")
        }
    }

    private func filterMenu<T: RawRepresentable & Hashable>(
        selection: Binding<T?>,
        label: String,
        options: [T],
        keyPrefix: String
    ) -> some View where T.RawValue == String {
        Menu {
            Picker(label, selection: selection) {
                Text("common.all").tag(nil as T?)
                ForEach(options, id: \.self) { option in
                    Text("\(keyPrefix).\(option.rawValue)").tag(option as T?)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.wrappedValue.map { "\(keyPrefix).\($0.rawValue)" } ?? label)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selection.wrappedValue == nil ? Color(.secondarySystemBackground) : Color.gymAccent.opacity(0.2))
            .foregroundStyle(selection.wrappedValue == nil ? Color.primary : Color.gymAccent)
            .clipShape(Capsule())
        }
    }
}

struct ExercisePickerRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                Spacer()
                if exercise.isCompound {
                    Text("exercise.compound.badge")
                        .font(.caption2.bold())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            HStack(spacing: 8) {
                Text("muscleGroup.\(exercise.primaryMuscle.rawValue)")
                Text("•")
                Text("equipment.\(exercise.equipment.rawValue)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

@Observable final class PreviewExercisePickerViewModel: ExercisePickerProtocol {
    var state: ViewState<[Exercise]> = .success(ProgramSamples.exercises)
    var transientError: AppError? = nil
    var searchText: String = ""
    var selectedMuscle: MuscleGroup? = nil
    var selectedEquipment: Equipment? = nil
    var selectedPattern: MovementPattern? = nil

    var filteredExercises: [Exercise] {
        ProgramSamples.exercises.filter { exercise in
            let matchesSearch = searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesMuscle = selectedMuscle == nil || exercise.primaryMuscle == selectedMuscle
            let matchesEquipment = selectedEquipment == nil || exercise.equipment == selectedEquipment
            let matchesPattern = selectedPattern == nil || exercise.movementPattern == selectedPattern
            return matchesSearch && matchesMuscle && matchesEquipment && matchesPattern
        }
    }

    func loadExercises() async {}
    func clearFilters() {
        selectedMuscle = nil
        selectedEquipment = nil
        selectedPattern = nil
    }
}

#Preview {
    ExercisePickerView(viewModel: PreviewExercisePickerViewModel()) { _ in }
}
