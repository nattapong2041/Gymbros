import SwiftUI

struct ExercisePickerView: View {
    @State var viewModel: ExercisePickerViewModel
    var onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar

                content
            }
            .navigationTitle("exercisePicker.title")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "exercisePicker.search.prompt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("exercisePicker.clearFilters.action") {
                        viewModel.clearFilters()
                    }
                    .disabled(viewModel.selectedMuscle == nil && viewModel.selectedEquipment == nil && viewModel.selectedPattern == nil && viewModel.searchText.isEmpty)
                }
            }
            .task {
                await viewModel.loadExercises()
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
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
            .padding()
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        case .success:
            if viewModel.filteredExercises.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                List {
                    ForEach(viewModel.filteredExercises) { exercise in
                        ExercisePickerRow(exercise: exercise)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(exercise)
                                dismiss()
                            }
                    }
                }
                .listStyle(.plain)
            }
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
            HStack {
                Text(selection.wrappedValue?.localizedTitleKey ?? LocalizedStringKey(label))
                Image(systemName: "chevron.down")
                    .font(.caption2.bold())
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal)
            .frame(minHeight: 48) // Mandated 48pt tap target
            // Active filter reads as violet-tinted; inactive stays neutral.
            .background(
                selection.wrappedValue == nil
                    ? Color(.tertiarySystemBackground)
                    : Color.accentColor.opacity(0.16)
            )
            .foregroundStyle(selection.wrappedValue == nil ? Color.primary : Color.accentColor)
            .clipShape(Capsule())
        }
    }
}

struct ExercisePickerRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            EquipmentIconView(equipment: exercise.equipment)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(exercise.name)
                        .font(.headline)

                    if exercise.isCompound {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                HStack {
                    Text(exercise.primaryMuscle.localizedTitleKey)
                    Text(verbatim: "•")
                    Text(exercise.equipment.localizedTitleKey)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
        }
    }
}

extension MuscleGroup {
    var systemImageName: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.walk"
        case .shoulders: "figure.arms.open"
        case .biceps, .triceps: "figure.strengthtraining.traditional"
        case .quads, .hamstrings, .glutes, .calves: "figure.strengthtraining.functional"
        case .core: "figure.core.training"
        case .forearms: "hand.raised.fill"
        case .traps: "figure.arms.open"
        }
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

extension Equipment: ExerciseFilterOption {}

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

#Preview("Success") {
    ExercisePickerView(viewModel: {
        let viewModel = ExercisePickerViewModel()
        viewModel.state = .success(ProgramSamples.exercises)
        return viewModel
    }()) { _ in }
}

#Preview("Loading") {
    ExercisePickerView(viewModel: {
        let viewModel = ExercisePickerViewModel()
        viewModel.state = .loading
        return viewModel
    }()) { _ in }
}

#Preview("Empty") {
    ExercisePickerView(viewModel: {
        let viewModel = ExercisePickerViewModel()
        viewModel.state = .empty
        return viewModel
    }()) { _ in }
}

#Preview("Error") {
    ExercisePickerView(viewModel: {
        let viewModel = ExercisePickerViewModel()
        viewModel.state = .error(.api(.server, statusCode: 500))
        return viewModel
    }()) { _ in }
}

