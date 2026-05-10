import Foundation
import Observation

@MainActor
@Observable
final class ExercisePickerViewModel: ExercisePickerProtocol {
    var state: ViewState<[Exercise]> = .idle
    var transientError: AppError?
    var searchText = ""
    var selectedMuscle: MuscleGroup?
    var selectedEquipment: Equipment?
    var selectedPattern: MovementPattern?

    private let repository: ExerciseRepositoryProviding

    var filteredExercises: [Exercise] {
        guard case let .success(exercises) = state else { return [] }
        return exercises.filter { exercise in
            ProgramViewModelSupport.matchesSearch(exercise, searchText: searchText)
                && (selectedMuscle == nil || exercise.primaryMuscle == selectedMuscle)
                && (selectedEquipment == nil || exercise.equipment == selectedEquipment)
                && (selectedPattern == nil || exercise.movementPattern == selectedPattern)
        }
    }

    init(repository: ExerciseRepositoryProviding? = nil) {
        self.repository = repository ?? ExerciseRepository()
    }

    func loadExercises() async {
        transientError = nil
        state = .loading
        do {
            let exercises = try await repository.fetchAll().sorted { $0.name < $1.name }
            state = exercises.isEmpty ? .empty : .success(exercises)
        } catch {
            let appError = ProgramViewModelSupport.appError(error, operation: "loadExercises")
            state = appError.isVisibleToUser ? .error(appError) : .idle
        }
    }

    func clearFilters() {
        searchText = ""
        selectedMuscle = nil
        selectedEquipment = nil
        selectedPattern = nil
    }
}
