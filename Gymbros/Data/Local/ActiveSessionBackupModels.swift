import Foundation

struct ActiveSessionSnapshot: Codable, Equatable {
    static let currentVersion = 3

    var version: Int
    var session: WorkoutSession
    var day: ProgramDay
    var programExercises: [ProgramExercise]
    var exerciseLookup: [UUID: Exercise]
    var rowStates: [ActiveSessionSetSnapshot]
    var activeTimer: RestTimerState?
    var finishedExerciseIds: [UUID]
    var currentExerciseIndex: Int
    var defaultWeights: [UUID: Double]?
    var updatedAt: Date

    init(
        version: Int = ActiveSessionSnapshot.currentVersion,
        session: WorkoutSession,
        day: ProgramDay,
        programExercises: [ProgramExercise],
        exerciseLookup: [UUID: Exercise],
        rowStates: [ActiveSessionSetSnapshot],
        activeTimer: RestTimerState?,
        finishedExerciseIds: [UUID] = [],
        currentExerciseIndex: Int = 0,
        defaultWeights: [UUID: Double]? = nil,
        updatedAt: Date
    ) {
        self.version = version
        self.session = session
        self.day = day
        self.programExercises = programExercises
        self.exerciseLookup = exerciseLookup
        self.rowStates = rowStates
        self.activeTimer = activeTimer
        self.finishedExerciseIds = finishedExerciseIds
        self.currentExerciseIndex = currentExerciseIndex
        self.defaultWeights = defaultWeights
        self.updatedAt = updatedAt
    }
}

struct ActiveSessionSetSnapshot: Codable, Equatable {
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

struct RestTimerState: Codable, Equatable {
    let sourceSetId: UUID
    let targetSeconds: Int
    let startedAt: Date
    let endsAt: Date

    var remainingSeconds: Int {
        remainingSeconds(at: Date())
    }

    var isComplete: Bool {
        remainingSeconds <= 0
    }

    func remainingSeconds(at date: Date) -> Int {
        max(0, Int(ceil(endsAt.timeIntervalSince(date))))
    }
}

