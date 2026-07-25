import SwiftUI

struct WorkoutSessionView: View {
    let state: ViewState<WorkoutSessionData>
    var activeTimer: RestTimerState?
    var lastSessionReferences: [UUID: LastSessionReference] = [:]
    var isFinishing: Bool = false
    var pendingRestore: Bool = false
    var isComebackMode: Bool = false
    var overloadHints: [UUID: Double] = [:]
    
    // Selection for TabView
    @Binding var currentExerciseIndex: Int
    
    // Actions
    var onRetry: () -> Void
    var onFinish: () -> Void
    var onAddSet: (UUID) -> Void // setId
    var onUpdateSet: (UUID, String, String, Double?) -> Void // setId
    var onCompleteSet: (UUID) -> Void // setId
    var onDeleteSet: (UUID) -> Void // setId
    var onFinishExercise: (UUID) -> Void // programExerciseId
    var onSwapExercise: (UUID) -> Void = { _ in } // programExerciseId
    var onStopTimer: () -> Void
    var onSkipTimer: () -> Void
    var onTimerComplete: () -> Void
    var onRestore: () -> Void
    var onDiscard: () -> Void
    
    var body: some View {
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
                                    .foregroundStyle(canFinishWorkout(data) ? Color.accentColor : Color.secondary)
                            }
                        }
                        .disabled(isFinishing || !canFinishWorkout(data))
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { pendingRestore },
                set: { _ in }
            )) {
                restoreSheetContent
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled()
            }
            .fullScreenCover(item: Binding(
                get: { activeTimer },
                set: { if $0 == nil { onStopTimer() } }
            )) { timerState in
                ZStack {
                    Color(uiColor: .systemBackground).ignoresSafeArea()

                    RestTimerRingView(
                        state: timerState,
                        onStop: onStopTimer,
                        onSkip: onSkipTimer,
                        onComplete: onTimerComplete
                    )
                    .padding(40)
                }
            }
    }
    
    @ViewBuilder
    private var restoreSheetContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "arrow.clockwise.icloud")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)

                Text("workout.restore.title")
                    .font(.headline)

                Text("workout.restore.message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button("workout.restore.action", action: onRestore)
                    .font(.headline)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Button("workout.restore.discard", role: .destructive, action: onDiscard)
                    .font(.headline)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .error(let error):
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text(LocalizedStringKey(error.titleKey))
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(LocalizedStringKey(error.messageKey))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                            exerciseLookup: data.exerciseLookup,
                            lastSessionReference: lastSessionReferences[data.exerciseSections[index].programExercise.id],
                            isComebackMode: isComebackMode,
                            overloadHint: overloadHints[data.exerciseSections[index].programExercise.id],
                            onAddSet: onAddSet,
                            onUpdateSet: onUpdateSet,
                            onCompleteSet: onCompleteSet,
                            onDeleteSet: onDeleteSet,
                            onFinishExercise: onFinishExercise,
                            onSwapExercise: onSwapExercise
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
            // Lime spark = progress/achievement, dark text per the brand contrast rule.
            Text(String(format: NSLocalizedString("workout.progress.done", comment: ""), finishedCount))
                .font(.system(.caption, design: .rounded).bold())
                .foregroundStyle(Color.black.opacity(0.82))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.brandSparkLime, in: Capsule())
                .contentTransition(.numericText())
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: finishedCount)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .overlay(Divider(), alignment: .bottom)
    }
    
    private func canFinishWorkout(_ data: WorkoutSessionData) -> Bool {
        // Spec: Finish Workout enables only when every exercise is finished
        !data.exerciseSections.isEmpty && data.exerciseSections.allSatisfy { $0.isFinished }
    }
}

extension RestTimerState: Identifiable {
    public var id: UUID { sourceSetId }
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

            onDeleteSet: { _ in },
            onFinishExercise: { _ in },
            onStopTimer: {},
            onSkipTimer: {},
            onTimerComplete: {},
            onRestore: {},
            onDiscard: {}
        )
    }
    .environment(AppPreferences())
}

#Preview("With Timer") {
    @Previewable @State var index = 0
    WorkoutSessionView(
        state: .success(WorkoutSessionData.mock),
            activeTimer: RestTimerState.mock,
            lastSessionReferences: [:],
            currentExerciseIndex: $index,
        onRetry: {},
        onFinish: {},
        onAddSet: { _ in },
        onUpdateSet: { _, _, _, _ in },
        onCompleteSet: { _ in },

        onDeleteSet: { _ in },
        onFinishExercise: { _ in },
        onStopTimer: {},
        onSkipTimer: {},
        onTimerComplete: {},
        onRestore: {},
        onDiscard: {}
    )
    .environment(AppPreferences())
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

        onDeleteSet: { _ in },
        onFinishExercise: { _ in },
        onStopTimer: {},
        onSkipTimer: {},
        onTimerComplete: {},
        onRestore: {},
        onDiscard: {}
    )
    .environment(AppPreferences())
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

        onDeleteSet: { _ in },
        onFinishExercise: { _ in },
        onStopTimer: {},
        onSkipTimer: {},
        onTimerComplete: {},
        onRestore: {},
        onDiscard: {}
    )
    .environment(AppPreferences())
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

        onDeleteSet: { _ in },
        onFinishExercise: { _ in },
        onStopTimer: {},
        onSkipTimer: {},
        onTimerComplete: {},
        onRestore: {},
        onDiscard: {}
    )
    .environment(AppPreferences())
}
