import SwiftUI

struct DayBuilderView<VM: DayBuilderProtocol>: View {
    @State var viewModel: VM
    @State private var isShowingExercisePicker = false
    @State private var exerciseToEdit: ProgramExercise?
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
                                exerciseToEdit = programExercise
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
            // ExercisePickerView will be next
            Text("Exercise Picker View")
        }
        .sheet(item: $exerciseToEdit) { programExercise in
            // ProgramExerciseEditorView will be implemented
            Text("Edit Exercise Prescription for \(programExercise.exerciseId.uuidString)")
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
                    Text("\(programExercise.targetSets)")
                        .font(.gymNumber(size: 18))
                    Text("x")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("\(programExercise.targetRepsMin)-\(programExercise.targetRepsMax)")
                        .font(.gymNumber(size: 18))
                }
            }

            HStack {
                Label("\(programExercise.targetRestSeconds)s", systemImage: "timer")
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

@Observable final class PreviewDayBuilderViewModel: DayBuilderProtocol {
    var dayId: UUID = ProgramSamples.upperDayId
    var state: ViewState<DayBuilderData> = .success(ProgramSamples.dayBuilderData)
    var transientError: AppError? = nil

    func loadDay() async {}
    func renameDay(_ name: String) async {
        if case .success(var data) = state {
            data.day.name = name
            state = .success(data)
        }
    }
    func addExercise(_ exercise: Exercise, form: ProgramExerciseForm) async {
        if case .success(var data) = state {
            let newEx = ProgramExercise(
                id: UUID(),
                programDayId: dayId,
                exerciseId: exercise.id,
                targetSets: form.targetSets,
                targetRepsMin: form.targetRepsMin,
                targetRepsMax: form.targetRepsMax,
                targetRestSeconds: form.targetRestSeconds,
                exerciseOrder: data.programExercises.count,
                notes: form.normalizedNotes,
                createdAt: Date()
            )
            data.programExercises.append(newEx)
            data.exerciseLookup[exercise.id] = exercise
            state = .success(data)
        }
    }
    func updateProgramExercise(_ programExercise: ProgramExercise, form: ProgramExerciseForm) async {
        if case .success(var data) = state {
            if let index = data.programExercises.firstIndex(where: { $0.id == programExercise.id }) {
                var updated = data.programExercises[index]
                updated.targetSets = form.targetSets
                updated.targetRepsMin = form.targetRepsMin
                updated.targetRepsMax = form.targetRepsMax
                updated.targetRestSeconds = form.targetRestSeconds
                updated.notes = form.normalizedNotes
                data.programExercises[index] = updated
                state = .success(data)
            }
        }
    }
    func deleteProgramExercise(_ programExercise: ProgramExercise) async {
        if case .success(var data) = state {
            data.programExercises.removeAll { $0.id == programExercise.id }
            state = .success(data)
        }
    }
    func moveProgramExercises(from sourceOffsets: IndexSet, to destinationOffset: Int) async {
        if case .success(var data) = state {
            data.programExercises.move(fromOffsets: sourceOffsets, toOffset: destinationOffset)
            state = .success(data)
        }
    }
}

#Preview {
    NavigationStack {
        DayBuilderView(viewModel: PreviewDayBuilderViewModel())
    }
}
