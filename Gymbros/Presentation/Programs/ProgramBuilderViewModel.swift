import Foundation
import Observation

@MainActor
@Observable
final class ProgramBuilderViewModel {
    let mode: ProgramBuilderMode
    var name: String
    var description: String
    var state: ViewState<Program> = .idle
    var transientError: AppError?

    private let repository: ProgramRepositoryProviding

    var canSave: Bool {
        if case .loading = state { return false }
        return (try? ProgramFormValidation.normalizedProgramName(name).get()) != nil
    }

    init(mode: ProgramBuilderMode, repository: ProgramRepositoryProviding? = nil) {
        self.mode = mode
        self.repository = repository ?? ProgramRepository()
        self.name = mode.existingProgram?.name ?? ""
        self.description = mode.existingProgram?.description ?? ""
    }

    func save() async {
        transientError = nil
        guard case let .success(trimmedName) = ProgramFormValidation.normalizedProgramName(name) else {
            transientError = .validation(.missingRequiredField)
            return
        }

        state = .loading
        let normalizedDescription = ProgramFormValidation.normalizedOptionalText(description)

        do {
            let saved: Program
            switch mode {
            case .create:
                saved = try await repository.createProgram(name: trimmedName, description: normalizedDescription)
            case let .edit(program):
                saved = try await repository.updateProgramMetadata(
                    id: program.id,
                    name: trimmedName,
                    description: normalizedDescription
                )
            }
            state = .success(saved)
        } catch {
            let appError = ProgramViewModelSupport.appError(error, operation: "saveProgram")
            state = appError.isVisibleToUser ? .error(appError) : .idle
        }
    }

    func resetForm() {
        name = mode.existingProgram?.name ?? ""
        description = mode.existingProgram?.description ?? ""
        transientError = nil
        state = .idle
    }
}
