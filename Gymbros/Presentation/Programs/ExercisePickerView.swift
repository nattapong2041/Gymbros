import SwiftUI

struct ExercisePickerView: View {
    @State var viewModel: ExercisePickerViewModel
    var onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                filterSection

                switch viewModel.state {
                case .idle, .loading:
                    ProgressView()
                case .empty:
                    ContentUnavailableView("exercisePicker.empty.title", systemImage: "figure.strengthtraining.traditional")
                case .error(let error):
                    ContentUnavailableView {
                        Label(LocalizedStringKey(error.titleKey), systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(LocalizedStringKey(error.messageKey))
                    } actions: {
                        Button("common.retry") {
                            Task { await viewModel.loadExercises() }
                        }
                    }
                case .success where viewModel.filteredExercises.isEmpty:
                    ContentUnavailableView.search(text: viewModel.searchText)
                case .success:
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
                        options: MuscleGroup.allCases
                    )

                    filterMenu(
                        selection: $viewModel.selectedEquipment,
                        label: "exercisePicker.filter.equipment",
                        options: Equipment.allCases
                    )

                    filterMenu(
                        selection: $viewModel.selectedPattern,
                        label: "exercisePicker.filter.pattern",
                        options: MovementPattern.allCases
                    )
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("exercisePicker.filters.section")
        }
    }

    private func filterMenu<T: ExerciseFilterOption>(
        selection: Binding<T?>,
        label: String,
        options: [T]
    ) -> some View {
        Menu {
            Picker(LocalizedStringKey(label), selection: selection) {
                Text("common.all").tag(nil as T?)
                ForEach(options, id: \.self) { option in
                    Text(option.localizedTitleKey)
                        .tag(option as T?)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.wrappedValue?.localizedTitleKey ?? LocalizedStringKey(label))
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
                Text(exercise.primaryMuscle.localizedTitleKey)
                Text(verbatim: "•")
                Text(exercise.equipment.localizedTitleKey)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private protocol ExerciseFilterOption: Hashable {
    var localizedTitleKey: LocalizedStringKey { get }
}

extension MuscleGroup: ExerciseFilterOption {
    var localizedTitleKey: LocalizedStringKey {
        switch self {
        case .chest: "muscleGroup.chest"
        case .back: "muscleGroup.back"
        case .shoulders: "muscleGroup.shoulders"
        case .biceps: "muscleGroup.biceps"
        case .triceps: "muscleGroup.triceps"
        case .quads: "muscleGroup.quads"
        case .hamstrings: "muscleGroup.hamstrings"
        case .glutes: "muscleGroup.glutes"
        case .calves: "muscleGroup.calves"
        case .core: "muscleGroup.core"
        case .forearms: "muscleGroup.forearms"
        case .traps: "muscleGroup.traps"
        }
    }
}

extension Equipment: ExerciseFilterOption {
    var localizedTitleKey: LocalizedStringKey {
        switch self {
        case .barbell: "equipment.barbell"
        case .dumbbell: "equipment.dumbbell"
        case .machine: "equipment.machine"
        case .cable: "equipment.cable"
        case .bodyweight: "equipment.bodyweight"
        case .kettlebell: "equipment.kettlebell"
        case .band: "equipment.band"
        }
    }
}

extension MovementPattern: ExerciseFilterOption {
    var localizedTitleKey: LocalizedStringKey {
        switch self {
        case .push: "movementPattern.push"
        case .pull: "movementPattern.pull"
        case .squat: "movementPattern.squat"
        case .hinge: "movementPattern.hinge"
        case .lunge: "movementPattern.lunge"
        case .carry: "movementPattern.carry"
        case .core: "movementPattern.core"
        }
    }
}

// MARK: - Previews

#Preview {
    ExercisePickerView(viewModel: {
        let viewModel = ExercisePickerViewModel()
        viewModel.state = .success(ProgramSamples.exercises)
        return viewModel
    }()) { _ in }
}
