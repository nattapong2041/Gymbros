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
                programs.flatMap(\.days).map { ($0.id, $0.name) },
                uniquingKeysWith: { first, _ in first }
            )

            logger.debug("Load success: \(sessions.count) sessions")
            state = sessions.isEmpty ? .empty : .success(HistoryData(sessions: sessions, dayNames: dayNames))
        } catch {
            let appError = ProgramViewModelSupport.appError(error, operation: "loadHistory")
            logger.error("Load failed: \(String(describing: appError))")
            if appError == .cancelled {
                state = .idle
            } else {
                state = .error(appError)
            }
        }
    }
}

#if DEBUG
extension HistoryViewModel {
    static var loading: HistoryViewModel {
        preview(.loading)
    }

    static var empty: HistoryViewModel {
        preview(.empty)
    }

    static var error: HistoryViewModel {
        preview(.error(.network(.offline)))
    }

    static var success: HistoryViewModel {
        preview(.success(.preview))
    }

    private static func preview(_ state: ViewState<HistoryData>) -> HistoryViewModel {
        let vm = HistoryViewModel()
        vm.state = state
        return vm
    }
}

extension HistoryData {
    static var preview: HistoryData {
        HistoryData(
            sessions: HistoryPreviewData.sessions,
            dayNames: [
                HistoryPreviewData.pushDayId: "Push Day A",
                HistoryPreviewData.legsDayId: "Legs Day"
            ]
        )
    }
}

private enum HistoryPreviewData {
    static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    static let userId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    static let pushDayId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    static let legsDayId = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    static var sessions: [WorkoutSession] {
        [
            WorkoutSession(id: UUID(), userId: userId, programDayId: pushDayId, startedAt: now.addingTimeInterval(-2 * 24 * 3600), endedAt: now.addingTimeInterval(-2 * 24 * 3600 + 3000), notes: nil, createdAt: now),
            WorkoutSession(id: UUID(), userId: userId, programDayId: legsDayId, startedAt: now.addingTimeInterval(-5 * 24 * 3600), endedAt: now.addingTimeInterval(-5 * 24 * 3600 + 3600), notes: nil, createdAt: now),
            WorkoutSession(id: UUID(), userId: userId, programDayId: nil, startedAt: now.addingTimeInterval(-9 * 24 * 3600), endedAt: now.addingTimeInterval(-9 * 24 * 3600 + 2700), notes: nil, createdAt: now)
        ]
    }

}
#endif
