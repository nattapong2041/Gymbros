import Foundation
import Observation

enum ProgramBuilderMode: Equatable {
    case create
    case edit(Program)

    var existingProgram: Program? {
        if case let .edit(program) = self {
            program
        } else {
            nil
        }
    }
}

@MainActor
protocol ProgramBuilderProtocol: Observable {
    var mode: ProgramBuilderMode { get }
    var name: String { get set }
    var description: String { get set }
    var state: ViewState<Program> { get }
    var transientError: AppError? { get }
    var canSave: Bool { get }

    func save() async
    func resetForm()
}
