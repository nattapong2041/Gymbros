import Foundation

struct WorkoutSessionData: Equatable {
    var session: WorkoutSession
    var day: ProgramDay
    var exerciseSections: [WorkoutExerciseSection]
    var exerciseLookup: [UUID: Exercise]
    var startedAt: Date
    var currentExerciseIndex: Int
}

struct WorkoutExerciseSection: Identifiable, Equatable {
    var programExercise: ProgramExercise
    var exercise: Exercise?
    var sets: [WorkoutSetRowState]
    var isFinished: Bool
    var finishedAt: Date?
    var defaultWeight: Double?
    /// The weight the Overload Advisor bumped this exercise from, if this is the very next
    /// session for it since that bump -- drives the encouragement badge and the RPE >= 9
    /// keep/revert prompt. Nil once this session has resolved the outcome.
    var pendingOverloadPreviousWeight: Double? = nil

    var id: UUID { programExercise.id }
}

struct WorkoutSetRowState: Identifiable, Equatable {
    let id: UUID
    let exerciseId: UUID
    let programExerciseId: UUID?
    var setNumber: Int
    var weightText: String
    var repsText: String
    var rpe: Double?
    var targetRestSeconds: Int?
    var isCompleted: Bool
}
