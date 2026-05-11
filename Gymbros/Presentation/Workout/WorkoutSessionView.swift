import SwiftUI

struct WorkoutSessionView: View {
    // In Task 4, this will be the real ViewModel.
    // For Task 2, we use a simple state container for previews.
    let state: ViewState<WorkoutSessionData>
    var activeTimer: RestTimerState?
    var isFinishing: Bool = false
    var pendingRestore: Bool = false
    
    // Actions
    var onRetry: () -> Void
    var onFinish: () -> Void
    var onAddSet: (UUID) -> Void // programExerciseId
    var onUpdateSet: (UUID, String, String, Double?) -> Void // setId
    var onCompleteSet: (UUID) -> Void // setId
    var onRetryUpload: (UUID) -> Void // setId
    var onDeleteSet: (UUID) -> Void // setId
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
                        if case .success = state {
                            Button(action: onFinish) {
                                if isFinishing {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("workout.finish") // workout.finish
                                        .fontWeight(.bold)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .disabled(isFinishing)
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
                
                Text("workout.error.message") // workout.error.message
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Button("workout.retry", action: onRetry) // workout.retry
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            
        case .empty:
            ContentUnavailableView(
                "workout.empty.title", // workout.empty.title
                systemImage: "dumbbell",
                description: Text("workout.empty.description") // workout.empty.description
            )
            
        case .success(let data):
            ScrollView {
                LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                    ForEach(data.exerciseSections) { section in
                        Section {
                            VStack(spacing: 0) {
                                ForEach(section.sets) { rowState in
                                    SetRowView(
                                        state: rowState,
                                        onUpdate: { w, r, rpe in
                                            onUpdateSet(rowState.id, w, r, rpe)
                                        },
                                        onComplete: {
                                            onCompleteSet(rowState.id)
                                        },
                                        onRetry: {
                                            onRetryUpload(rowState.id)
                                        },
                                        onDelete: {
                                            onDeleteSet(rowState.id)
                                        }
                                    )
                                    
                                    if rowState.id != section.sets.last?.id {
                                        Divider()
                                            .padding(.leading, 36)
                                    }
                                }
                                
                                Button(action: { onAddSet(section.programExercise.id) }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("workout.set.add") // workout.set.add
                                    }
                                    .font(.system(.subheadline, design: .rounded).bold())
                                    .foregroundStyle(.blue)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48) // HIG
                                }
                                .padding(.top, 8)
                            }
                            .padding(.horizontal)
                        } header: {
                            exerciseHeader(section)
                        }
                    }
                    
                    // Bottom spacing for "Finish" button if it was at the bottom
                    Color.clear.frame(height: 100)
                }
            }
            .background(Color.gymBackground)
        }
    }
    
    private var navigationTitle: String {
        if case .success(let data) = state {
            return data.day.name
        }
        return "workout.title" // workout.title
    }
    
    private func exerciseHeader(_ section: WorkoutExerciseSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.exercise?.name ?? "Exercise")
                .font(.system(.headline, design: .rounded))
            
            Text("\(section.programExercise.targetSets) × \(section.programExercise.targetRepsMin)-\(section.programExercise.targetRepsMax) • \(section.programExercise.targetRestSeconds)s")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymBackground)
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
    NavigationStack {
        WorkoutSessionView(
            state: .success(WorkoutSessionData.mock),
            onRetry: {},
            onFinish: {},
            onAddSet: { _ in },
            onUpdateSet: { _, _, _, _ in },
            onCompleteSet: { _ in },
            onRetryUpload: { _ in },
            onDeleteSet: { _ in },
            onStopTimer: {},
            onSkipTimer: {},
            onRestore: {},
            onDiscard: {}
        )
    }
}

#Preview("With Timer") {
    WorkoutSessionView(
        state: .success(WorkoutSessionData.mock),
        activeTimer: RestTimerState.mock,
        onRetry: {},
        onFinish: {},
        onAddSet: { _ in },
        onUpdateSet: { _, _, _, _ in },
        onCompleteSet: { _ in },
        onRetryUpload: { _ in },
        onDeleteSet: { _ in },
        onStopTimer: {},
        onSkipTimer: {},
        onRestore: {},
        onDiscard: {}
    )
}

#Preview("Restore Prompt") {
    WorkoutSessionView(
        state: .loading,
        pendingRestore: true,
        onRetry: {},
        onFinish: {},
        onAddSet: { _ in },
        onUpdateSet: { _, _, _, _ in },
        onCompleteSet: { _ in },
        onRetryUpload: { _ in },
        onDeleteSet: { _ in },
        onStopTimer: {},
        onSkipTimer: {},
        onRestore: {},
        onDiscard: {}
    )
}

#Preview("Empty") {
    WorkoutSessionView(
        state: .empty,
        onRetry: {},
        onFinish: {},
        onAddSet: { _ in },
        onUpdateSet: { _, _, _, _ in },
        onCompleteSet: { _ in },
        onRetryUpload: { _ in },
        onDeleteSet: { _ in },
        onStopTimer: {},
        onSkipTimer: {},
        onRestore: {},
        onDiscard: {}
    )
}

#Preview("Error") {
    WorkoutSessionView(
        state: .error(.api(.server, statusCode: 500)),
        onRetry: {},
        onFinish: {},
        onAddSet: { _ in },
        onUpdateSet: { _, _, _, _ in },
        onCompleteSet: { _ in },
        onRetryUpload: { _ in },
        onDeleteSet: { _ in },
        onStopTimer: {},
        onSkipTimer: {},
        onRestore: {},
        onDiscard: {}
    )
}
