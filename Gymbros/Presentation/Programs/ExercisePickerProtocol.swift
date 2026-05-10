import Foundation
import Observation

@MainActor
protocol ExercisePickerProtocol: Observable {
    var state: ViewState<[Exercise]> { get }
    var transientError: AppError? { get }
    var searchText: String { get set }
    var selectedMuscle: MuscleGroup? { get set }
    var selectedEquipment: Equipment? { get set }
    var selectedPattern: MovementPattern? { get set }
    var filteredExercises: [Exercise] { get }

    func loadExercises() async
    func clearFilters()
}
