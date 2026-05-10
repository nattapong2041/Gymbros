import SwiftUI

struct ProgramExerciseEditorView: View {
    @Binding var form: ProgramExerciseForm
    var exerciseName: String
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let restPresets = [60, 90, 120, 180, 300]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $form.targetSets, in: 1...10) {
                        HStack {
                            Text("programExercise.sets")
                            Spacer()
                            Text("\(form.targetSets)")
                                .font(.gymNumber(size: 20))
                                .foregroundStyle(Color.gymAccent)
                        }
                    }
                } header: {
                    Text("programExercise.sets.section")
                }

                Section {
                    Stepper(value: $form.targetRepsMin, in: 1...100) {
                        HStack {
                            Text("programExercise.repsMin")
                            Spacer()
                            Text("\(form.targetRepsMin)")
                                .font(.gymNumber(size: 20))
                        }
                    }

                    Stepper(value: $form.targetRepsMax, in: form.targetRepsMin...100) {
                        HStack {
                            Text("programExercise.repsMax")
                            Spacer()
                            Text("\(form.targetRepsMax)")
                                .font(.gymNumber(size: 20))
                        }
                    }
                } header: {
                    Text("programExercise.reps.section")
                }

                Section {
                    Picker("programExercise.rest.presets", selection: $form.targetRestSeconds) {
                        ForEach(restPresets, id: \.self) { seconds in
                            Text("\(seconds)s").tag(seconds)
                        }
                        if !restPresets.contains(form.targetRestSeconds) {
                            Text("\(form.targetRestSeconds)s").tag(form.targetRestSeconds)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $form.targetRestSeconds, in: 15...600, step: 5) {
                        HStack {
                            Text("programExercise.rest.custom")
                            Spacer()
                            Text("\(form.targetRestSeconds)s")
                                .font(.gymNumber(size: 20))
                        }
                    }
                } header: {
                    Text("programExercise.rest.section")
                }

                Section {
                    TextField("programExercise.notes.placeholder", text: $form.notes, axis: .vertical)
                        .lineLimit(3...5)
                } header: {
                    Text("programExercise.notes.section")
                }
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(form.validate() != nil)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var form = ProgramExerciseForm(programExercise: ProgramSamples.benchProgramExercise)
    return ProgramExerciseEditorView(
        form: $form,
        exerciseName: "Bench Press",
        onSave: {}
    )
}
