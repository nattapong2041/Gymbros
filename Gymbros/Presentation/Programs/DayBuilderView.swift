import SwiftUI

struct DayBuilderView: View {
    @State var viewModel: DayBuilderViewModel
    @State private var isShowingExercisePicker = false
    @State private var editingForm: ProgramExerciseForm?
    @State private var isShowingRenameAlert = false
    @State private var isShowingWorkout = false
    @State private var renamedDayName = ""

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
            case .empty:
                emptyState
            case .success(let data):
                List {
                    Section {
                        ForEach(data.programExercises) { programExercise in
                            let exercise = data.exerciseLookup[programExercise.exerciseId]
                            ProgramExerciseRow(
                                programExercise: programExercise,
                                exercise: exercise
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingForm = ProgramExerciseForm(programExercise: programExercise)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteProgramExercise(programExercise) }
                                } label: {
                                    Label("common.delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                        .onMove { source, destination in
                            Task { await viewModel.moveProgramExercises(from: source, to: destination) }
                        }
                    } header: {
                        HStack {
                            Label("dayBuilder.exercises.section", systemImage: "dumbbell.fill")
                            Spacer()
                            Button {
                                isShowingExercisePicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("dayBuilder.addExercise.action")
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .navigationTitle(data.day.name)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if data.programExercises.isEmpty == false {
                            Button {
                                isShowingWorkout = true
                            } label: {
                                Label("workout.start", systemImage: "play.fill")
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            renamedDayName = data.day.name
                            isShowingRenameAlert = true
                        } label: {
                            Image(systemName: "pencil.line")
                        }
                    }
                }
                case .error(let error):
                    ContentUnavailableView {
                        Label(LocalizedStringKey(error.titleKey), systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(LocalizedStringKey(error.messageKey))
                    } actions: {
                        Button("common.retry") {
                            Task { await viewModel.loadDay() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            await viewModel.loadDay()
        }
        .navigationDestination(isPresented: $isShowingWorkout) {
            WorkoutSessionScreen(programDayId: viewModel.dayId)
        }
        .alert("dayBuilder.renameDay.title", isPresented: $isShowingRenameAlert) {
            TextField("programDetail.dayName.placeholder", text: $renamedDayName)
            Button("common.save") {
                Task { await viewModel.renameDay(renamedDayName) }
            }
            Button("common.cancel", role: .cancel) {}
        }
        .transientErrorAlert(error: Binding(
            get: { viewModel.transientError },
            set: { viewModel.transientError = $0 }
        ))
        .sheet(isPresented: $isShowingExercisePicker) {
            ExercisePickerView(viewModel: ExercisePickerViewModel()) { exercise in
                Task { await viewModel.addExercise(exercise, form: ProgramExerciseForm(exerciseId: exercise.id)) }
            }
        }
        .sheet(item: $editingForm) { form in
            ProgramExerciseEditorView(
                form: Binding(
                    get: { editingForm ?? form },
                    set: { updatedForm in
                        guard editingForm != nil else { return }
                        editingForm = updatedForm
                    }
                ),
                exerciseName: viewModel.state.value?.exerciseLookup[form.exerciseId]?.name ?? String(localized: "common.unknown"),
                onSave: {
                    let currentForm = editingForm ?? form
                    editingForm = nil
                    if let pe = viewModel.state.value?.programExercises.first(where: { $0.id == currentForm.id }) {
                        Task { await viewModel.updateProgramExercise(pe, form: currentForm) }
                    }
                }
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("dayBuilder.empty.title", systemImage: "figure.strengthtraining.traditional")
        } description: {
            Text("dayBuilder.empty.message")
        } actions: {
            Button("dayBuilder.addExercise.action") {
                isShowingExercisePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct ProgramExerciseRow: View {
    let programExercise: ProgramExercise
    let exercise: Exercise?
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        HStack(spacing: 12) {
            EquipmentIconView(equipment: exercise?.equipment)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise?.name ?? "programExercise.unknownExercise")
                    .font(.headline)

                HStack {
                    Text(String(format: String(localized: "programExercise.setsFormat"), programExercise.targetSets))
                    Text(verbatim: "•")
                    Text(String(
                        format: String(localized: "programExercise.repsFormat"),
                        programExercise.targetRepsMin,
                        programExercise.targetRepsMax
                    ))
                    Text(verbatim: "•")
                    Text(String(format: String(localized: "programExercise.restFormat"), programExercise.targetRestSeconds))
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let targetWeight = programExercise.targetWeight {
                    Text(verbatim: "\(appPreferences.weightUnit.formattedKilograms(targetWeight)) \(appPreferences.weightUnit.localizedAbbreviation)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let notes = programExercise.notes, !notes.isEmpty {
                    HStack {
                        Image(systemName: "note.text")
                        Text(notes)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary) // Increased contrast from .tertiary
                    .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2.bold())
                .foregroundStyle(.secondary) // Increased contrast from .tertiary
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview("Success") {
    NavigationStack {
        DayBuilderView(viewModel: {
            let vm = DayBuilderViewModel(dayId: ProgramSamples.upperDayId)
            vm.state = .success(ProgramSamples.dayBuilderData)
            return vm
        }())
    }
    .environment(AppPreferences())
}

#Preview("Loading") {
    NavigationStack {
        DayBuilderView(viewModel: {
            let vm = DayBuilderViewModel(dayId: ProgramSamples.upperDayId)
            vm.state = .loading
            return vm
        }())
    }
}

#Preview("Empty") {
    NavigationStack {
        DayBuilderView(viewModel: {
            let vm = DayBuilderViewModel(dayId: ProgramSamples.upperDayId)
            vm.state = .empty
            return vm
        }())
    }
}

#Preview("Error") {
    NavigationStack {
        DayBuilderView(viewModel: {
            let vm = DayBuilderViewModel(dayId: ProgramSamples.upperDayId)
            vm.state = .error(.network(.offline))
            return vm
        }())
    }
}
