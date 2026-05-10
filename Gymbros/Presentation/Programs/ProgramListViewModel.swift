import Foundation
import Observation

@MainActor
@Observable
final class ProgramListViewModel {
    var state: ViewState<[Program]> = .idle
    var transientError: AppError?

    private let repository: ProgramRepositoryProviding

    init(repository: ProgramRepositoryProviding? = nil) {
        self.repository = repository ?? ProgramRepository()
    }

    func loadPrograms(isRefreshing: Bool = false) async {
        transientError = nil
        if !isRefreshing {
            state = .loading
        }

        do {
            let programs = ProgramViewModelSupport.sortedPrograms(try await repository.fetchAll())
            state = programs.isEmpty ? .empty : .success(programs)
        } catch {
            let appError = ProgramViewModelSupport.appError(error, operation: "loadPrograms")
            if isRefreshing {
                transientError = appError.isVisibleToUser ? appError : nil
            } else if appError == .cancelled {
                state = .idle
            } else {
                state = .error(appError)
            }
        }
    }

    func setActive(program: Program) async {
        transientError = nil
        do {
            try await repository.setActive(programId: program.id)
            await loadPrograms(isRefreshing: true)
        } catch {
            let appError = ProgramViewModelSupport.appError(error, operation: "setActiveProgram")
            transientError = appError.isVisibleToUser ? appError : nil
        }
    }

    func deleteProgram(_ program: Program) async {
        transientError = nil
        do {
            try await repository.delete(id: program.id)
            await loadPrograms(isRefreshing: true)
        } catch {
            let appError = ProgramViewModelSupport.appError(error, operation: "deleteProgram")
            transientError = appError.isVisibleToUser ? appError : nil
        }
    }

    func fetchPrograms() async {
        await loadPrograms()
    }

    func toggleActive(program: Program) async {
        await setActive(program: program)
    }
}
