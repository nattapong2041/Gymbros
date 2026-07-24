import SwiftUI

struct WorkoutSessionScreen: View {
    let programDayId: UUID
    var initialProgramExerciseId: UUID?
    var recommendation: TodayRecommendation = .normalDefault

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @State private var viewModel = WorkoutSessionViewModel()
    @State private var hasStarted = false

    var body: some View {
        WorkoutSessionView(
            state: viewModel.state,
            activeTimer: viewModel.activeTimer,
            lastSessionReferences: viewModel.lastSessionReferences,
            isFinishing: viewModel.isFinishing,
            pendingRestore: viewModel.pendingRestore != nil,
            isComebackMode: viewModel.isComebackMode,
            overloadHints: viewModel.recommendation.overloadHints,
            currentExerciseIndex: currentExerciseIndex,
            onRetry: {
                Task { await startWorkout() }
            },
            onFinish: {
                Task { await finishWorkout() }
            },
            onAddSet: { setId in
                Task { await viewModel.addSet(after: setId) }
            },
            onUpdateSet: { setId, weightText, repsText, rpe in
                Task {
                    await viewModel.updateDraft(
                        setId: setId,
                        weightText: weightText,
                        repsText: repsText,
                        rpe: rpe
                    )
                }
            },
            onCompleteSet: { setId in
                Task { await viewModel.completeSet(setId: setId) }
            },
            onDeleteSet: { setId in
                Task { await viewModel.deleteSet(setId: setId) }
            },
            onFinishExercise: { programExerciseId in
                Task { await viewModel.finishExercise(programExerciseId: programExerciseId) }
            },
            onSwapExercise: { programExerciseId in
                Task { await viewModel.presentSubstituteOptions(programExerciseId: programExerciseId) }
            },
            onStopTimer: {
                viewModel.stopRestTimer()
            },
            onSkipTimer: {
                viewModel.stopRestTimer()
            },
            onTimerComplete: {
                Task { await viewModel.markRestTimerComplete() }
            },
            onRestore: {
                Task { await restoreWorkout() }
            },
            onDiscard: {
                Task { await discardAndStartWorkout() }
            }
        )
        .transientErrorAlert(error: Binding(
            get: { viewModel.transientError },
            set: { viewModel.transientError = $0 }
        ))
        .alert(
            "workout.overload.outcome.title",
            isPresented: isOverloadOutcomePromptPresented,
            presenting: viewModel.overloadOutcomePrompt,
            actions: overloadOutcomeActions,
            message: overloadOutcomeMessageView
        )
        .sheet(item: Binding(
            get: { viewModel.substitutePrompt },
            set: { if $0 == nil { viewModel.substitutePrompt = nil } }
        )) { prompt in
            SubstituteCandidateSheet(prompt: prompt) { exercise in
                Task { await viewModel.selectSubstitute(exercise) }
            }
        }
        .task {
            guard hasStarted == false else { return }
            hasStarted = true
            viewModel.recommendation = recommendation
            viewModel.updateWeightUnit(appPreferences.weightUnit)
            await viewModel.checkForRestore()
            guard viewModel.pendingRestore == nil else { return }
            await startWorkout()
        }
        .onChange(of: appPreferences.weightUnit) { _, newUnit in
            viewModel.updateWeightUnit(newUnit)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.prepareForScreenExit()
                    dismiss()
                } label: {
                    Label("workout.leave.button", systemImage: "chevron.left")
                }
            }
        }
        .onAppear {
            postWorkoutScreenVisibility(true)
        }
        .onDisappear {
            postWorkoutScreenVisibility(false)
        }
    }

    private var currentExerciseIndex: Binding<Int> {
        Binding(
            get: { viewModel.state.value?.currentExerciseIndex ?? 0 },
            set: { viewModel.goToExercise(index: $0) }
        )
    }

    private var isOverloadOutcomePromptPresented: Binding<Bool> {
        Binding(
            get: { viewModel.overloadOutcomePrompt != nil },
            set: { isPresented in
                if isPresented == false { viewModel.overloadOutcomePrompt = nil }
            }
        )
    }

    @ViewBuilder
    private func overloadOutcomeActions(_ prompt: OverloadOutcomePrompt) -> some View {
        Button("workout.overload.outcome.keep") {
            viewModel.keepNewOverloadWeight()
        }
        Button("workout.overload.outcome.revert") {
            Task { await viewModel.revertOverloadWeight() }
        }
    }

    private func overloadOutcomeMessageView(_ prompt: OverloadOutcomePrompt) -> some View {
        Text(overloadOutcomeMessage(prompt))
    }

    private func startWorkout() async {
        await viewModel.start(programDayId: programDayId)
        moveToInitialExerciseIfNeeded()
    }

    private func restoreWorkout() async {
        guard let snapshot = viewModel.pendingRestore else { return }
        await viewModel.restore(snapshot)
        moveToInitialExerciseIfNeeded()
    }

    private func discardAndStartWorkout() async {
        guard let snapshot = viewModel.pendingRestore else { return }
        await viewModel.discardRestore(snapshot)
        await startWorkout()
    }

    private func finishWorkout() async {
        await viewModel.finishSession()
        if viewModel.state.value?.session.endedAt != nil {
            dismiss()
        }
    }

    private func moveToInitialExerciseIfNeeded() {
        guard let initialProgramExerciseId,
              let sections = viewModel.state.value?.exerciseSections,
              let index = sections.firstIndex(where: { $0.programExercise.id == initialProgramExerciseId }) else {
            return
        }
        viewModel.goToExercise(index: index)
    }

    private func overloadOutcomeMessage(_ prompt: OverloadOutcomePrompt) -> String {
        let previousWeightText = "\(appPreferences.weightUnit.formattedKilograms(prompt.previousWeight)) \(appPreferences.weightUnit.localizedAbbreviation)"
        return String(
            format: String(localized: "workout.overload.outcome.message"),
            prompt.exerciseName,
            previousWeightText
        )
    }

    private func postWorkoutScreenVisibility(_ isVisible: Bool) {
        NotificationCenter.default.post(
            name: .workoutSessionScreenVisibilityDidChange,
            object: nil,
            userInfo: [WorkoutSessionVisibilityNotification.isVisibleKey: isVisible]
        )
    }
}
