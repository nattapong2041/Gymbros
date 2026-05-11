import SwiftUI

struct WorkoutSessionView: View {
    // In Task 4, this will be the real ViewModel.
    // For Task 2, we use a simple state container for previews.
    let state: ViewState<WorkoutSessionData>
    var activeTimer: RestTimerState?
    var isFinishing: Bool = false
    var pendingRestore: Bool = false
    
    // Selection for TabView
    @Binding var currentExerciseIndex: Int
    
    // Actions
    var onRetry: () -> Void
    var onFinish: () -> Void
    var onAddSet: (UUID) -> Void // programExerciseId
    var onUpdateSet: (UUID, String, String, Double?) -> Void // setId
    var onCompleteSet: (UUID) -> Void // setId
    var onRetryUpload: (UUID) -> Void // setId
    var onDeleteSet: (UUID) -> Void // setId
    var onFinishExercise: (UUID) -> Void // programExerciseId
    var onStopTimer: () -> Void
    var onSkipTimer: () -> Void
    var onRestore: () -> Void
    var onDiscard: () -> Void
    
    var body: some View {
        ZStack {
            content
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if case .success(let data) = state {
                            Button(action: onFinish) {
                                if isFinishing {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("workout.finish")
                                        .fontWeight(.bold)
                                        .foregroundStyle(canFinishWorkout(data) ? .blue : .secondary)
                                }
                            }
                            .disabled(isFinishing || !canFinishWorkout(data))
                        }
                    }
                }
            
            // Restore Prompt Overlay
            if pendingRestore {
                restoreOverlay
            }
            
            // Rest Timer Overlay
            if let timerState = activeTimer {
                timerOverlay(timerState)
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .error(let error):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text("workout.error.message")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Button("workout.retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            
        case .empty:
            ContentUnavailableView(
                "workout.empty.title",
                systemImage: "dumbbell",
                description: Text("workout.empty.description")
            )
            
        case .success(let data):
            VStack(spacing: 0) {
                progressHeader(data)
                
                TabView(selection: $currentExerciseIndex) {
                    ForEach(data.exerciseSections.indices, id: \.self) { index in
                        WorkoutExercisePageView(
                            section: data.exerciseSections[index],
                            onAddSet: onAddSet,
                            onUpdateSet: onUpdateSet,
                            onCompleteSet: onCompleteSet,
                            onRetryUpload: onRetryUpload,
                            onDeleteSet: onDeleteSet,
                            onFinishExercise: onFinishExercise
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .id(data.exerciseSections.count) // Ensure TabView re-renders if sections change
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    private var navigationTitle: String {
        if case .success(let data) = state {
            return data.day.name
        }
        return "workout.title"
    }
    
    private func progressHeader(_ data: WorkoutSessionData) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(data.day.name)
                    .font(.system(.subheadline, design: .rounded).bold())
                
                Text(String(format: NSLocalizedString("workout.progress.count", comment: ""), currentExerciseIndex + 1, data.exerciseSections.count))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            let finishedCount = data.exerciseSections.filter { $0.isFinished }.count
            Text(String(format: NSLocalizedString("workout.progress.done", comment: ""), finishedCount))
                .font(.system(.caption, design: .rounded).bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .overlay(Divider(), alignment: .bottom)
    }
    
    private func canFinishWorkout(_ data: WorkoutSessionData) -> Bool {
        // Spec: Finish Workout enables only when every exercise is finished
        !data.exerciseSections.isEmpty && data.exerciseSections.allSatisfy { $0.isFinished }
    }
    
    private var restoreOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise.icloud")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    
                    Text("workout.restore.title") // workout.restore.title
                        .font(.headline)
                    
                    Text("workout.restore.message") // workout.restore.message
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    Button(action: onRestore) {
                        Text("workout.restore.action") // workout.restore.action
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button(action: onDiscard) {
                        Text("workout.restore.discard") // workout.restore.discard
                            .font(.headline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
            }
            .padding(24)
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(40)
            .shadow(radius: 10)
        }
    }
    
    private func timerOverlay(_ timerState: RestTimerState) -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            
            RestTimerRingView(
                state: timerState,
                onStop: onStopTimer,
                onSkip: onSkipTimer
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(40)
            .shadow(radius: 20)
        }
        .transition(.opacity.combined(with: .scale))
    }
}

#Preview("Success") {
    @Previewable @State var index = 0
    NavigationStack {
        WorkoutSessionView(
            state: .success(WorkoutSessionData.mock),
            currentExerciseIndex: $index,
            onRetry: {},
            onFinish: {},
            onAddSet: { _ in },
            onUpdateSet: { _, _, _, _ in },
            onCompleteSet: { _ in },
            onRetryUpload: { _ in },
            onDeleteSet: { _ in },
            onFinishExercise: { _ in },
            onStopTimer: {},
            onSkipTimer: {},
            onRestore: {},
            onDiscard: {}
        )
    }
}

#Preview("With Timer") {
    @Previewable @State var index = 0
    WorkoutSessionView(
        state: .success(WorkoutSessionData.mock),
        activeTimer: RestTimerState.mock,
        currentExerciseIndex: $index,
        onRetry: {},
        onFinish: {},
        onAddSet: { _ in },
        onUpdateSet: { _, _, _, _ in },
        onCompleteSet: { _ in },
        onRetryUpload: { _ in },
        onDeleteSet: { _ in },
        onFinishExercise: { _ in },
        onStopTimer: {},
        onSkipTimer: {},
        onRestore: {},
        onDiscard: {}
    )
}

#Preview("Restore Prompt") {
    @Previewable @State var index = 0
    WorkoutSessionView(
        state: .loading,
        pendingRestore: true,
        currentExerciseIndex: $index,
        onRetry: {},
        onFinish: {},
        onAddSet: { _ in },
        onUpdateSet: { _, _, _, _ in },
        onCompleteSet: { _ in },
        onRetryUpload: { _ in },
        onDeleteSet: { _ in },
        onFinishExercise: { _ in },
        onStopTimer: {},
        onSkipTimer: {},
        onRestore: {},
        onDiscard: {}
    )
}

#Preview("Empty") {
    @Previewable @State var index = 0
    WorkoutSessionView(
        state: .empty,
        currentExerciseIndex: $index,
        onRetry: {},
        onFinish: {},
        onAddSet: { _ in },
        onUpdateSet: { _, _, _, _ in },
        onCompleteSet: { _ in },
        onRetryUpload: { _ in },
        onDeleteSet: { _ in },
        onFinishExercise: { _ in },
        onStopTimer: {},
        onSkipTimer: {},
        onRestore: {},
        onDiscard: {}
    )
}

#Preview("Error") {
    @Previewable @State var index = 0
    WorkoutSessionView(
        state: .error(.api(.server, statusCode: 500)),
        currentExerciseIndex: $index,
        onRetry: {},
        onFinish: {},
        onAddSet: { _ in },
        onUpdateSet: { _, _, _, _ in },
        onCompleteSet: { _ in },
        onRetryUpload: { _ in },
        onDeleteSet: { _ in },
        onFinishExercise: { _ in },
        onStopTimer: {},
        onSkipTimer: {},
        onRestore: {},
        onDiscard: {}
    )
}
