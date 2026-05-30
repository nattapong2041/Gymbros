import SwiftUI

struct WorkoutSessionScreen: View {
    let programDayId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @State private var viewModel = WorkoutSessionViewModel()
    @State private var hasStarted = false

    var body: some View {
        WorkoutSessionView(
            state: viewModel.state,
            activeTimer: viewModel.activeTimer,
            isFinishing: viewModel.isFinishing,
            pendingRestore: viewModel.pendingRestore != nil,
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
            onStopTimer: {
                viewModel.stopRestTimer()
            },
            onSkipTimer: {
                viewModel.stopRestTimer()
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
        .task {
            guard hasStarted == false else { return }
            hasStarted = true
            viewModel.updateWeightUnit(appPreferences.weightUnit)
            await viewModel.checkForRestore()
            guard viewModel.pendingRestore == nil else { return }
            await startWorkout()
        }
        .onChange(of: appPreferences.weightUnit) { _, newUnit in
            viewModel.updateWeightUnit(newUnit)
        }
    }

    private var currentExerciseIndex: Binding<Int> {
        Binding(
            get: { viewModel.state.value?.currentExerciseIndex ?? 0 },
            set: { viewModel.goToExercise(index: $0) }
        )
    }

    private func startWorkout() async {
        await viewModel.start(programDayId: programDayId)
    }

    private func restoreWorkout() async {
        guard let snapshot = viewModel.pendingRestore else { return }
        await viewModel.restore(snapshot)
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
}
