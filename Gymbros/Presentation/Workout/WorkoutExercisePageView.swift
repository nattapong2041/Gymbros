import SwiftUI

struct WorkoutExercisePageView: View {
    let section: WorkoutExerciseSection
    
    // Actions
    var onAddSet: (UUID) -> Void // setId
    var onUpdateSet: (UUID, String, String, Double?) -> Void // setId
    var onCompleteSet: (UUID) -> Void // setId
    var onRetryUpload: (UUID) -> Void // setId
    var onDeleteSet: (UUID) -> Void // setId
    var onFinishExercise: (UUID) -> Void // programExerciseId
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                exerciseHeader
                
                VStack(spacing: 0) {
                    ForEach(section.sets) { rowState in
                        SetRowView(
                            state: rowState,
                            isReadOnly: section.isFinished,
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
                    
                    if !section.isFinished, let lastSetId = section.sets.last?.id {
                        Button(action: { onAddSet(lastSetId) }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("workout.set.add")
                            }
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
                
                footerAction
            }
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    private var exerciseHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.exercise?.name ?? String(localized: "workout.exercise.unknownExercise"))
                .font(.system(.title2, design: .rounded).bold())
                .accessibilityAddTraits(.isHeader)
            
            HStack(spacing: 12) {
                Label(
                    String(format: String(localized: "programExercise.setsFormat"), section.programExercise.targetSets),
                    systemImage: "list.bullet"
                )
                Label(
                    String(
                        format: String(localized: "programExercise.repsFormat"),
                        section.programExercise.targetRepsMin,
                        section.programExercise.targetRepsMax
                    ),
                    systemImage: "repeat"
                )
                Label(
                    String(format: String(localized: "programExercise.restFormat"), section.programExercise.targetRestSeconds),
                    systemImage: "timer"
                )
            }
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
            
            if let targetWeight = section.programExercise.targetWeight {
                HStack {
                    Text("workout.exercise.target_weight")
                    Text("\(targetWeight, specifier: "%.1f")")
                        .fontWeight(.bold)
                    Text("kg")
                }
                .font(.system(.caption, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
                .foregroundStyle(.blue)
            }
            
            if let notes = section.programExercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }
    
    @ViewBuilder
    private var footerAction: some View {
        if section.isFinished {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("workout.exercise.finished")
            }
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.green)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        } else {
            Button("workout.exercise.finish_or_skip") {
                onFinishExercise(section.programExercise.id)
            }
            .font(.system(.headline, design: .rounded))
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(!canFinish)
            .padding(.horizontal)
        }
    }
    
    private var canFinish: Bool {
        true
    }
}

#Preview("Active") {
    WorkoutExercisePageView(
        section: WorkoutSessionData.mock.exerciseSections[0],
        onAddSet: { _ in },
        onUpdateSet: { _, _, _, _ in },
        onCompleteSet: { _ in },
        onRetryUpload: { _ in },
        onDeleteSet: { _ in },
        onFinishExercise: { _ in }
    )
}

#Preview("Finished") {
    var section = WorkoutSessionData.mock.exerciseSections[0]
    section.isFinished = true
    return WorkoutExercisePageView(
        section: section,
        onAddSet: { _ in },
        onUpdateSet: { _, _, _, _ in },
        onCompleteSet: { _ in },
        onRetryUpload: { _ in },
        onDeleteSet: { _ in },
        onFinishExercise: { _ in }
    )
}
