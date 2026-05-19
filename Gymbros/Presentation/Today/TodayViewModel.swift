import Foundation
import Observation

struct TodayData {
    var activeProgram: Program?
    var nextDay: ProgramDay?
    var recentSessions: [WorkoutSession]
    var streakWeeks: Int
    var lastSessionDate: Date?
    var isWelcomeBack: Bool
}

@MainActor
@Observable
final class TodayViewModel {
    var state: ViewState<TodayData> = .idle
    var transientError: AppError?

    private let programRepository: ProgramRepositoryProviding
    private let workoutRepository: WorkoutRepositoryProviding
    private let streakService = StreakService()

    init(
        programRepository: ProgramRepositoryProviding? = nil,
        workoutRepository: WorkoutRepositoryProviding? = nil
    ) {
        self.programRepository = programRepository ?? ProgramRepository()
        self.workoutRepository = workoutRepository ?? WorkoutRepository()
    }

    func load() async {
        state = .loading
        await fetch()
    }

    func refresh() async {
        await fetch()
    }

    private func fetch() async {
        do {
            async let fetchedProgram = programRepository.fetchActive()
            async let fetchedHistory = workoutRepository.fetchHistory(limit: 50)
            let (activeProgram, allSessions) = try await (fetchedProgram, fetchedHistory)

            let completed = allSessions.filter(\.isComplete).sorted { $0.startedAt > $1.startedAt }
            let streakWeeks = streakService.streak(from: completed)
            let lastSessionDate = completed.first?.startedAt

            let nextDay = deriveNextDay(from: activeProgram, recentHistory: completed)

            let isWelcomeBack: Bool
            if let lastDate = lastSessionDate {
                isWelcomeBack = Date.now.timeIntervalSince(lastDate) >= 7 * 24 * 3600
            } else {
                isWelcomeBack = activeProgram != nil
            }

            let data = TodayData(
                activeProgram: activeProgram,
                nextDay: nextDay,
                recentSessions: completed,
                streakWeeks: streakWeeks,
                lastSessionDate: lastSessionDate,
                isWelcomeBack: isWelcomeBack
            )
            state = .success(data)
        } catch {
            let appError = ErrorMapper.map(error, context: .init(operation: "loadToday"))
            if appError != .cancelled {
                state = .error(appError)
            }
        }
    }

    private func deriveNextDay(from program: Program?, recentHistory: [WorkoutSession]) -> ProgramDay? {
        guard let program, !program.days.isEmpty else { return nil }

        let sorted = program.days.sorted { $0.dayOrder < $1.dayOrder }

        guard let lastSession = recentHistory.first else {
            return sorted.first
        }

        guard let lastDayId = lastSession.programDayId,
              let lastIndex = sorted.firstIndex(where: { $0.id == lastDayId }) else {
            // nil or stale programDayId — fall back to first day (lowest dayOrder)
            return sorted.first
        }

        let nextIndex = (lastIndex + 1) % sorted.count
        return sorted[nextIndex]
    }
}
