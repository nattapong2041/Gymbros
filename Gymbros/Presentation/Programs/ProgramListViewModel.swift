import Foundation
import Observation

@MainActor
@Observable
final class ProgramListViewModel {
    var state: ViewState<[Program]> = .idle
    
    private let repository: ProgramRepository
    
    init(repository: ProgramRepository? = nil) {
        self.repository = repository ?? ProgramRepository()
    }
    
    func fetchPrograms() async {
        state = .loading
        do {
            let programs = try await repository.fetchAll()
            if programs.isEmpty {
                state = .empty
            } else {
                state = .success(programs)
            }
        } catch {
            state = .error(ErrorMapper.map(error, context: .init(operation: "fetchPrograms")))
        }
    }
    
    func toggleActive(program: Program) async {
        do {
            try await repository.setActive(programId: program.id)
            await fetchPrograms() // Refresh list to update badges
        } catch {
            // We could show a transient error here, but for now just log it
            print("Failed to set active program: \(error)")
        }
    }
}
