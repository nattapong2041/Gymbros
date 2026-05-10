import Foundation
import Observation

@MainActor
protocol ProgramListProtocol: Observable {
    var state: ViewState<[Program]> { get }
    var transientError: AppError? { get }

    func loadPrograms() async
    func setActive(program: Program) async
    func deleteProgram(_ program: Program) async
}
