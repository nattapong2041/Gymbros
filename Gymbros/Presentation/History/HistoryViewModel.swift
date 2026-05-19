import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.nattapongsawa.gymbros", category: "HistoryViewModel")

struct HistoryData {
    var sessions: [WorkoutSession]
    var dayNames: [UUID: String]
}

@MainActor
@Observable
final class HistoryViewModel {
    var state: ViewState<HistoryData> = .idle
    var transientError: AppError?

    private let workoutRepository: WorkoutRepositoryProviding
    private let programRepository: ProgramRepositoryProviding

    init(
        workoutRepository: WorkoutRepositoryProviding? = nil,
        programRepository: ProgramRepositoryProviding? = nil
    ) {
        self.workoutRepository = workoutRepository ?? WorkoutRepository()
        self.programRepository = programRepository ?? ProgramRepository()
    }

    func load() async {
        logger.debug("Starting load")
        transientError = nil
        state = .loading
        do {
            async let sessionsTask = workoutRepository.fetchHistory(limit: 50)
            async let programsTask = programRepository.fetchAll()

            let (sessions, programs) = try await (sessionsTask, programsTask)

            let dayNames = Dictionary(
                programs.flatMap { $0.days }.map { ($0.id, $0.name) },
                uniquingKeysWith: { first, _ in first }
            )

            logger.debug("Load success — \(sessions.count) sessions")
            state = sessions.isEmpty ? .empty : .success(HistoryData(sessions: sessions, dayNames: dayNames))
        } catch {
            logger.error("Load failed: \(error.localizedDescription)")
            let appError = ProgramViewModelSupport.appError(error, operation: "loadHistory")
            if appError == .cancelled {
                logger.debug("Load cancelled.")
                state = .idle
            } else {
                state = .error(appError)
            }
        }
    }
}
