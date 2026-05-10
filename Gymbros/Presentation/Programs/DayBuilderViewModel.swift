import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.nattapongsawa.gymbros", category: "DayBuilderViewModel")

@MainActor
@Observable
final class DayBuilderViewModel {
    let dayId: UUID
    var state: ViewState<DayBuilderData> = .idle
    var transientError: AppError?

    private let programRepository: ProgramRepositoryProviding
    private let exerciseRepository: ExerciseRepositoryProviding

    init(
        dayId: UUID,
        programRepository: ProgramRepositoryProviding? = nil,
        exerciseRepository: ExerciseRepositoryProviding? = nil
    ) {
        self.dayId = dayId
        self.programRepository = programRepository ?? ProgramRepository()
        self.exerciseRepository = exerciseRepository ?? ExerciseRepository()
    }

    func loadDay() async {
        logger.debug("Starting loadDay for \(self.dayId)")
        transientError = nil
        state = .loading
        do {
            logger.debug("Fetching program data in parallel...")
            async let dayTask = programRepository.fetchDay(id: self.dayId)
            async let programExercisesTask = programRepository.fetchProgramExercises(dayId: self.dayId)
            async let exercisesTask = exerciseRepository.fetchAll()

            let (day, programExercises, exercises) = try await (dayTask, programExercisesTask, exercisesTask)

            logger.debug("Load success.")
            state = .success(DayBuilderData(
                day: day,
                programExercises: ProgramOrderNormalizer.normalizeProgramExercises(programExercises),
                exerciseLookup: ProgramViewModelSupport.exerciseLookup(from: exercises)
            ))
        } catch {
            logger.error("Load failed: \(error.localizedDescription)")
            let appError = ProgramViewModelSupport.appError(error, operation: "loadProgramDay")
            if appError == .cancelled {
                logger.debug("Load cancelled.")
                state = .idle
            } else {
                state = .error(appError)
            }
        }
    }

    func renameDay(_ name: String) async {
        guard case let .success(data) = state else {
            transientError = .notFound
            return
        }
        guard case let .success(trimmedName) = ProgramFormValidation.normalizedDayName(name) else {
            transientError = .validation(.missingRequiredField)
            return
        }

        await performDayMutation(operation: "renameProgramDay") {
            _ = try await programRepository.updateDay(
                id: data.day.id,
                name: trimmedName,
                order: data.day.dayOrder
            )
        }
    }

    func addExercise(_ exercise: Exercise, form: ProgramExerciseForm) async {
        guard case let .success(data) = state else {
            transientError = .notFound
            return
        }
        guard form.validate() == nil else {
            transientError = .validation(.invalidInput)
            return
        }

        await performDayMutation(operation: "addProgramExercise") {
            _ = try await programRepository.createProgramExercise(
                dayId: dayId,
                exerciseId: exercise.id,
                targetSets: form.targetSets,
                targetRepsMin: form.targetRepsMin,
                targetRepsMax: form.targetRepsMax,
                targetRestSeconds: form.targetRestSeconds,
                order: data.programExercises.count,
                notes: form.normalizedNotes
            )
        }
    }

    func updateProgramExercise(_ programExercise: ProgramExercise, form: ProgramExerciseForm) async {
        guard form.validate() == nil else {
            transientError = .validation(.invalidInput)
            return
        }

        var updated = programExercise
        updated.targetSets = form.targetSets
        updated.targetRepsMin = form.targetRepsMin
        updated.targetRepsMax = form.targetRepsMax
        updated.targetRestSeconds = form.targetRestSeconds
        updated.notes = form.normalizedNotes

        await performDayMutation(operation: "updateProgramExercise") {
            _ = try await programRepository.updateProgramExercise(updated)
        }
    }

    func deleteProgramExercise(_ programExercise: ProgramExercise) async {
        guard case let .success(data) = state else {
            transientError = .notFound
            return
        }

        let remainingExercises = ProgramOrderNormalizer.normalizeProgramExercises(
            data.programExercises.filter { $0.id != programExercise.id }
        )
        await performDayMutation(operation: "deleteProgramExercise") {
            try await programRepository.deleteProgramExercise(id: programExercise.id)
            try await programRepository.reorderProgramExercises(remainingExercises)
        }
    }

    func moveProgramExercises(from sourceOffsets: IndexSet, to destinationOffset: Int) async {
        guard case let .success(data) = state else {
            transientError = .notFound
            return
        }

        let movedExercises = ProgramOrderNormalizer.moveProgramExercises(
            data.programExercises,
            from: sourceOffsets,
            to: destinationOffset
        )
        state = .success(DayBuilderData(
            day: data.day,
            programExercises: movedExercises,
            exerciseLookup: data.exerciseLookup
        ))

        do {
            try await programRepository.reorderProgramExercises(movedExercises)
            await loadDay()
        } catch {
            state = .success(data)
            setTransientError(error, operation: "moveProgramExercises")
        }
    }

    private func performDayMutation(operation: String, _ mutation: () async throws -> Void) async {
        transientError = nil
        do {
            try await mutation()
            await loadDay()
        } catch {
            setTransientError(error, operation: operation)
        }
    }

    private func setTransientError(_ error: Error, operation: String) {
        let appError = ProgramViewModelSupport.appError(error, operation: operation)
        transientError = appError.isVisibleToUser ? appError : nil
    }
}
