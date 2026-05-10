import Foundation
import Observation

struct ProgramDetailData: Equatable {
    var program: Program
    var days: [ProgramDay]
    var exerciseLookup: [UUID: Exercise]
}

@MainActor
protocol ProgramDetailProtocol: Observable {
    var programId: UUID { get }
    var state: ViewState<ProgramDetailData> { get }
    var transientError: AppError? { get }

    func loadProgram() async
    func setActive() async
    func deleteProgram() async
    func addDay(name: String) async
    func renameDay(_ day: ProgramDay, name: String) async
    func deleteDay(_ day: ProgramDay) async
    func moveDays(from sourceOffsets: IndexSet, to destinationOffset: Int) async
}
