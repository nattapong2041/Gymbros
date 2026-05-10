import Foundation
import Observation

@MainActor
@Observable
final class ProgramDetailViewModel: ProgramDetailProtocol {
    let programId: UUID
    var state: ViewState<ProgramDetailData> = .idle
    var transientError: AppError?

    private let programRepository: ProgramRepositoryProviding
    private let exerciseRepository: ExerciseRepositoryProviding

    init(
        programId: UUID,
        programRepository: ProgramRepositoryProviding? = nil,
        exerciseRepository: ExerciseRepositoryProviding? = nil
    ) {
        self.programId = programId
        self.programRepository = programRepository ?? ProgramRepository()
        self.exerciseRepository = exerciseRepository ?? ExerciseRepository()
    }

    func loadProgram() async {
        transientError = nil
        state = .loading
        do {
            let program = try await programRepository.fetchFull(id: programId)
            let exercises = try await exerciseRepository.fetchAll()
            state = .success(makeDetailData(program: program, exercises: exercises))
        } catch {
            let appError = ProgramViewModelSupport.appError(error, operation: "loadProgramDetail")
            state = appError.isVisibleToUser ? .error(appError) : .idle
        }
    }

    func setActive() async {
        await performDetailMutation(operation: "setActiveProgram") {
            try await programRepository.setActive(programId: programId)
        }
    }

    func deleteProgram() async {
        transientError = nil
        do {
            try await programRepository.delete(id: programId)
            state = .empty
        } catch {
            setTransientError(error, operation: "deleteProgram")
        }
    }

    func addDay(name: String) async {
        guard case let .success(data) = state else {
            transientError = .notFound
            return
        }
        guard case let .success(trimmedName) = ProgramFormValidation.normalizedDayName(name) else {
            transientError = .validation(.missingRequiredField)
            return
        }

        await performDetailMutation(operation: "addProgramDay") {
            _ = try await programRepository.createDay(
                programId: programId,
                name: trimmedName,
                order: data.days.count
            )
        }
    }

    func renameDay(_ day: ProgramDay, name: String) async {
        guard case let .success(trimmedName) = ProgramFormValidation.normalizedDayName(name) else {
            transientError = .validation(.missingRequiredField)
            return
        }

        await performDetailMutation(operation: "renameProgramDay") {
            _ = try await programRepository.updateDay(id: day.id, name: trimmedName, order: day.dayOrder)
        }
    }

    func deleteDay(_ day: ProgramDay) async {
        guard case let .success(data) = state else {
            transientError = .notFound
            return
        }

        let remainingDays = ProgramOrderNormalizer.normalizeDays(data.days.filter { $0.id != day.id })
        await performDetailMutation(operation: "deleteProgramDay") {
            try await programRepository.deleteDay(id: day.id)
            try await programRepository.reorderDays(remainingDays)
        }
    }

    func moveDays(from sourceOffsets: IndexSet, to destinationOffset: Int) async {
        guard case let .success(data) = state else {
            transientError = .notFound
            return
        }

        let movedDays = ProgramOrderNormalizer.moveDays(data.days, from: sourceOffsets, to: destinationOffset)
        var updatedProgram = data.program
        updatedProgram.days = movedDays
        state = .success(ProgramDetailData(
            program: updatedProgram,
            days: movedDays,
            exerciseLookup: data.exerciseLookup
        ))

        do {
            try await programRepository.reorderDays(movedDays)
            await loadProgram()
        } catch {
            state = .success(data)
            setTransientError(error, operation: "moveProgramDays")
        }
    }

    private func performDetailMutation(operation: String, _ mutation: () async throws -> Void) async {
        transientError = nil
        do {
            try await mutation()
            await loadProgram()
        } catch {
            setTransientError(error, operation: operation)
        }
    }

    private func makeDetailData(program: Program, exercises: [Exercise]) -> ProgramDetailData {
        let days = ProgramOrderNormalizer.normalizeDays(program.days)
        var normalizedProgram = program
        normalizedProgram.days = days
        return ProgramDetailData(
            program: normalizedProgram,
            days: days,
            exerciseLookup: ProgramViewModelSupport.exerciseLookup(from: exercises)
        )
    }

    private func setTransientError(_ error: Error, operation: String) {
        let appError = ProgramViewModelSupport.appError(error, operation: operation)
        transientError = appError.isVisibleToUser ? appError : nil
    }
}
