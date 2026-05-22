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
