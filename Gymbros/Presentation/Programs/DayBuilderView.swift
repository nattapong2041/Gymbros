import SwiftUI

struct DayBuilderView: View {
    @State var viewModel: DayBuilderViewModel
    @State private var isShowingExercisePicker = false
    @State private var editingForm: ProgramExerciseForm?
    @State private var isShowingRenameAlert = false
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
                            }
                        }
                        .onMove { source, destination in
                            Task { await viewModel.moveProgramExercises(from: source, to: destination) }
                        }
                    } header: {
                        HStack {
                            Text("dayBuilder.exercises.section")
                            Spacer()
                            Button {
                                isShowingExercisePicker = true
                            } label: {
                                Label("dayBuilder.addExercise.action", systemImage: "plus")
                                    .font(.subheadline.bold())
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .navigationTitle(data.day.name)
                .toolbar {
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
                    Label(error.titleKey, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.messageKey)
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
        .alert("dayBuilder.renameDay.title", isPresented: $isShowingRenameAlert) {
            TextField("programDetail.dayName.placeholder", text: $renamedDayName)
            Button("common.save") {
                Task { await viewModel.renameDay(renamedDayName) }
            }
            Button("common.cancel", role: .cancel) {}
        }
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
            .tint(.gymAccent)
        }
    }
}

struct ProgramExerciseRow: View {
    let programExercise: ProgramExercise
    let exercise: Exercise?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(exercise?.name ?? "programExercise.unknownExercise")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Text(verbatim: "\(programExercise.targetSets)")
                        .font(.gymNumber(size: 18))
                    Text(verbatim: "x")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(verbatim: "\(programExercise.targetRepsMin)-\(programExercise.targetRepsMax)")
                        .font(.gymNumber(size: 18))
                }
            }

            HStack {
                Label {
                    Text(verbatim: "\(programExercise.targetRestSeconds)s")
                } icon: {
                    Image(systemName: "timer")
                }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let notes = programExercise.notes, !notes.isEmpty {
                    Spacer()
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundStyle(Color.gymAccent)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        DayBuilderView(viewModel: {
            let vm = DayBuilderViewModel(dayId: ProgramSamples.upperDayId)
            vm.state = .success(ProgramSamples.dayBuilderData)
            return vm
        }())
    }
}
