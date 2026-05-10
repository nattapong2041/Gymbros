import Foundation
import Observation

struct DayBuilderData: Equatable {
    var day: ProgramDay
    var programExercises: [ProgramExercise]
    var exerciseLookup: [UUID: Exercise]
}

@MainActor
protocol DayBuilderProtocol: Observable {
    var dayId: UUID { get }
    var state: ViewState<DayBuilderData> { get }
    var transientError: AppError? { get }

    func loadDay() async
    func renameDay(_ name: String) async
    func addExercise(_ exercise: Exercise, form: ProgramExerciseForm) async
    func updateProgramExercise(_ programExercise: ProgramExercise, form: ProgramExerciseForm) async
    func deleteProgramExercise(_ programExercise: ProgramExercise) async
    func moveProgramExercises(from sourceOffsets: IndexSet, to destinationOffset: Int) async
}
