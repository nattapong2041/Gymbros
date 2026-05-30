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
                            Text(verbatim: "\(form.targetSets)")
                                .font(.gymNumber(size: 20))
                                .foregroundStyle(.primary)
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
                            Text(verbatim: "\(form.targetRepsMin)")
                                .font(.gymNumber(size: 20))
                        }
                    }

                    Stepper(value: $form.targetRepsMax, in: form.targetRepsMin...100) {
                        HStack {
                            Text("programExercise.repsMax")
                            Spacer()
                            Text(verbatim: "\(form.targetRepsMax)")
                                .font(.gymNumber(size: 20))
                        }
                    }
                } header: {
                    Text("programExercise.reps.section")
                }

                Section {
                    Picker("programExercise.rest.presets", selection: $form.targetRestSeconds) {
                        ForEach(restPresets, id: \.self) { seconds in
                            Text(verbatim: "\(seconds)s").tag(seconds)
                        }
                        if !restPresets.contains(form.targetRestSeconds) {
                            Text(verbatim: "\(form.targetRestSeconds)s").tag(form.targetRestSeconds)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $form.targetRestSeconds, in: 15...600, step: 5) {
                        HStack {
                            Text("programExercise.rest.custom")
                            Spacer()
                            Text(verbatim: "\(form.targetRestSeconds)s")
                                .font(.gymNumber(size: 20))
                        }
                    }
                } header: {
                    Text("programExercise.rest.section")
                }

                Section {
                    TargetWeightField(form: $form)
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
                    Button("common.cancel", role: .cancel) {
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

private struct TargetWeightField: View {
    @Binding var form: ProgramExerciseForm

    @Environment(AppPreferences.self) private var appPreferences
    @State private var displayWeightText = ""
    @State private var didSyncWeightText = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text("program.exercise.target_weight")
            Text(verbatim: appPreferences.weightUnit.localizedAbbreviation)
                .foregroundStyle(.secondary)
            Spacer()
            TextField("0", text: $displayWeightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .onChange(of: displayWeightText) { _, newValue in
                    form.targetWeightText = appPreferences.weightUnit.kilogramText(fromDisplayText: newValue)
                }
        }
        .onAppear(perform: syncDisplayWeight)
        .onChange(of: appPreferences.weightUnit) { _, _ in
            syncDisplayWeight()
        }
        .onChange(of: form.targetWeightText) { _, _ in
            guard isFocused == false else { return }
            syncDisplayWeight()
        }
    }

    private func syncDisplayWeight() {
        guard didSyncWeightText == false || isFocused == false else { return }
        displayWeightText = appPreferences.weightUnit.displayText(fromKilogramText: form.targetWeightText)
        didSyncWeightText = true
    }
}

#Preview("Default") {
    @Previewable @State var form = ProgramExerciseForm(programExercise: ProgramSamples.benchProgramExercise)
    return ProgramExerciseEditorView(
        form: $form,
        exerciseName: "Bench Press",
        onSave: {}
    )
    .environment(AppPreferences())
}

#Preview("Invalid Input") {
    @Previewable @State var form = ProgramExerciseForm(
        targetSets: 0, // Invalid
        targetWeightText: "invalid" // Invalid
    )
    return ProgramExerciseEditorView(
        form: $form,
        exerciseName: "Bench Press",
        onSave: {}
    )
    .environment(AppPreferences())
}
