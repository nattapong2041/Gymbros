import Foundation
import Observation

struct StalledExercise: Equatable {
    let programExercise: ProgramExercise
    let exerciseName: String
    let weight: Double
}

struct TodayData {
    var activeProgram: Program?
    var nextDay: ProgramDay?
    var recentSessions: [WorkoutSession]
    var streakWeeks: Int
    var lastSessionDate: Date?
    var isWelcomeBack: Bool
    var recommendation: TodayRecommendation = .normalDefault
    var rampPreview: [UUID: RampDecision] = [:]
    var trainingPhase: TrainingPhase? = nil
    var stalledExercise: StalledExercise? = nil
}

@MainActor
@Observable
final class TodayViewModel {
    var state: ViewState<TodayData> = .idle
    var transientError: AppError?

    private let programRepository: ProgramRepositoryProviding
    private let workoutRepository: WorkoutRepositoryProviding
    private let exerciseRepository: ExerciseRepositoryProviding
    private let profileRepository: ProfileRepositoryProviding
    private let streakService = StreakService()
    private let engine: NextBestSessionEngine
    private let analytics: AnalyticsTracking
    private let overloadSnoozeStore: OverloadAdvisorSnoozing
    private let overloadSuggestionTracker: OverloadSuggestionTracking

    /// Comeback baseline/current tracking is budgeted by session count: post-gap sessions plus
    /// this many recent pre-gap sessions. Gaps can be arbitrarily old, so a calendar window
    /// doesn't fit this use -- it's a fixed count of sessions immediately around the gap.
    private static let baselineSessionWindow = 10

    /// On normal (non-comeback) days, set fetches are instead bounded by calendar time, not
    /// count: StallDetector evaluates a mesocycle-style window (StallDetector.windowDays), and
    /// how many sessions fall inside that window depends entirely on training frequency and
    /// program day-count, which a fixed row count can't predict. This cap only guards against
    /// runaway cost for very high-frequency training within the window.
    private static let stallDetectionFetchCap = 30

    init(
        programRepository: ProgramRepositoryProviding? = nil,
        workoutRepository: WorkoutRepositoryProviding? = nil,
        exerciseRepository: ExerciseRepositoryProviding? = nil,
        profileRepository: ProfileRepositoryProviding? = nil,
        engine: NextBestSessionEngine = NextBestSessionEngine(),
        analytics: AnalyticsTracking? = nil,
        overloadSnoozeStore: OverloadAdvisorSnoozing? = nil,
        overloadSuggestionTracker: OverloadSuggestionTracking? = nil
    ) {
        self.programRepository = programRepository ?? ProgramRepository()
        self.workoutRepository = workoutRepository ?? WorkoutRepository()
        self.exerciseRepository = exerciseRepository ?? ExerciseRepository()
        self.profileRepository = profileRepository ?? ProfileRepository()
        self.engine = engine
        self.analytics = analytics ?? AnalyticsProvider.makeDefault()
        self.overloadSnoozeStore = overloadSnoozeStore ?? OverloadAdvisorSnoozeStore()
        self.overloadSuggestionTracker = overloadSuggestionTracker ?? OverloadSuggestionTracker()
    }

    func trackComebackCardShown() {
        analytics.track(.comebackCardShown)
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

            let now = Date.now
            let sets = await fetchBudgetedSets(for: completed, now: now)
            let recommendation = engine.recommend(program: activeProgram, history: completed, sets: sets, now: now)
            let trainingPhase = await fetchTrainingPhase()
            let stalledExercise = recommendation.mode.isComeback
                ? nil
                : await findStalledExercise(
                    in: recommendation.programDay,
                    completed: completed,
                    sets: sets,
                    trainingPhase: trainingPhase,
                    now: now
                )

            let isWelcomeBack: Bool
            if let lastDate = lastSessionDate {
                isWelcomeBack = now.timeIntervalSince(lastDate) >= 7 * 24 * 3600
            } else {
                isWelcomeBack = activeProgram != nil
            }

            state = .success(TodayData(
                activeProgram: activeProgram,
                nextDay: recommendation.programDay,
                recentSessions: completed,
                streakWeeks: streakWeeks,
                lastSessionDate: lastSessionDate,
                isWelcomeBack: isWelcomeBack,
                recommendation: recommendation,
                rampPreview: recommendation.rampPreview,
                trainingPhase: trainingPhase,
                stalledExercise: stalledExercise
            ))
        } catch {
            let appError = ErrorMapper.map(error, context: .init(operation: "loadToday"))
            if appError != .cancelled {
                state = .error(appError)
            }
        }
    }

    private func fetchBudgetedSets(for completed: [WorkoutSession], now: Date) async -> [UUID: [WorkoutSet]] {
        guard completed.isEmpty == false else { return [:] }

        let sessionsToFetch: [WorkoutSession]
        if NextBestSessionEngine.hasGapCandidate(history: completed, now: now) {
            let sessionBudget = Self.baselineSessionWindow + NextBestSessionEngine.boundedExitSessionCount
            sessionsToFetch = Array(completed.prefix(sessionBudget))
        } else {
            let cutoff = now.addingTimeInterval(-TimeInterval(StallDetector.windowDays) * 86_400)
            sessionsToFetch = Array(
                completed
                    .filter { ($0.endedAt ?? $0.startedAt) >= cutoff }
                    .prefix(Self.stallDetectionFetchCap)
            )
        }

        var sets: [UUID: [WorkoutSet]] = [:]
        for session in sessionsToFetch {
            do {
                sets[session.id] = try await workoutRepository.fetchSets(sessionId: session.id)
            } catch {
                // A failed set fetch degrades the recommendation, not the screen.
                break
            }
        }
        return sets
    }

    private func fetchTrainingPhase() async -> TrainingPhase? {
        (try? await profileRepository.fetchCurrentProfile())?.trainingPhase
    }

    private func findStalledExercise(
        in day: ProgramDay?,
        completed: [WorkoutSession],
        sets: [UUID: [WorkoutSet]],
        trainingPhase: TrainingPhase?,
        now: Date
    ) async -> StalledExercise? {
        guard trainingPhase != .cut, trainingPhase != .maintain else { return nil }
        guard let day, day.exercises.isEmpty == false else { return nil }

        let exercises = (try? await exerciseRepository.fetchAll()) ?? []
        let exercisesById = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        let detector = StallDetector()

        for programExercise in day.exercises.sorted(by: { $0.exerciseOrder < $1.exerciseOrder }) {
            guard overloadSnoozeStore.isSnoozed(programExerciseId: programExercise.id, now: now) == false else { continue }
            guard detector.isStalled(
                exerciseId: programExercise.exerciseId,
                recentSessions: completed,
                sets: sets,
                now: now
            ) else { continue }
            guard let weight = Self.topWeight(forExerciseId: programExercise.exerciseId, sessions: completed, sets: sets) else {
                continue
            }
            let name = exercisesById[programExercise.exerciseId]?.displayName
                ?? String(localized: "workout.exercise.unknownExercise")
            return StalledExercise(programExercise: programExercise, exerciseName: name, weight: weight)
        }
        return nil
    }

    private static func topWeight(forExerciseId exerciseId: UUID, sessions: [WorkoutSession], sets: [UUID: [WorkoutSet]]) -> Double? {
        for session in sessions {
            if let weight = (sets[session.id] ?? []).filter({ $0.exerciseId == exerciseId }).map(\.weight).max() {
                return weight
            }
        }
        return nil
    }

    func tryOverloadSuggestion(_ stalled: StalledExercise) async {
        var updated = stalled.programExercise
        updated.targetWeight = stalled.weight + ProgressiveOverloadEngine.weightIncrementKg
        do {
            _ = try await programRepository.updateProgramExercise(updated)
            overloadSuggestionTracker.recordSuggestion(
                programExerciseId: stalled.programExercise.id,
                previousWeight: stalled.weight
            )
            clearStalledExercise()
        } catch {
            let appError = ErrorMapper.map(error, context: .init(operation: "applyOverloadSuggestion"))
            if appError != .cancelled {
                transientError = appError
            }
        }
    }

    func snoozeOverloadSuggestion(_ stalled: StalledExercise) {
        overloadSnoozeStore.snooze(programExerciseId: stalled.programExercise.id, now: .now)
        clearStalledExercise()
    }

    private func clearStalledExercise() {
        guard case .success(var data) = state else { return }
        data.stalledExercise = nil
        state = .success(data)
    }
}

#if DEBUG
extension TodayViewModel {
    static let morning = Date(timeIntervalSince1970: 1_778_367_600)
    static let afternoon = Date(timeIntervalSince1970: 1_778_396_400)
    static let evening = Date(timeIntervalSince1970: 1_778_414_400)

    static var loading: TodayViewModel {
        preview(.loading)
    }

    static var error: TodayViewModel {
        preview(.error(.network(.offline)))
    }

    static var noProgram: TodayViewModel {
        preview(.success(.noProgram))
    }

    static var hasProgramNoHistory: TodayViewModel {
        preview(.success(.hasProgramNoHistory))
    }

    static var hasProgramWithStreak: TodayViewModel {
        preview(.success(.hasProgramWithStreak))
    }

    static var welcomeBack: TodayViewModel {
        preview(.success(.welcomeBack))
    }

    private static func preview(_ state: ViewState<TodayData>) -> TodayViewModel {
        let vm = TodayViewModel()
        vm.state = state
        return vm
    }
}

extension TodayData {
    static var noProgram: TodayData {
        TodayData(
            activeProgram: nil,
            nextDay: nil,
            recentSessions: [],
            streakWeeks: 0,
            lastSessionDate: nil,
            isWelcomeBack: false
        )
    }

    static var hasProgramNoHistory: TodayData {
        TodayData(
            activeProgram: TodayPreviewData.activeProgram,
            nextDay: TodayPreviewData.upperDay,
            recentSessions: [],
            streakWeeks: 0,
            lastSessionDate: nil,
            isWelcomeBack: true
        )
    }

    static var hasProgramWithStreak: TodayData {
        TodayData(
            activeProgram: TodayPreviewData.activeProgram,
            nextDay: TodayPreviewData.lowerDay,
            recentSessions: [TodayPreviewData.lastSession],
            streakWeeks: 3,
            lastSessionDate: TodayPreviewData.lastSession.startedAt,
            isWelcomeBack: false
        )
    }

    static var welcomeBack: TodayData {
        TodayData(
            activeProgram: TodayPreviewData.activeProgram,
            nextDay: TodayPreviewData.upperDay,
            recentSessions: [TodayPreviewData.olderSession],
            streakWeeks: 0,
            lastSessionDate: TodayPreviewData.olderSession.startedAt,
            isWelcomeBack: true
        )
    }
}

private enum TodayPreviewData {
    static var activeProgram: Program { ProgramSamples.program }
    static var upperDay: ProgramDay {
        var day = ProgramSamples.days[0]
        day.exercises = [
            ProgramSamples.benchProgramExercise,
            accessoryExercise(programDayId: day.id, order: 1, sets: 3, repsMin: 10, repsMax: 12, restSeconds: 75),
            accessoryExercise(programDayId: day.id, order: 2, sets: 2, repsMin: 12, repsMax: 15, restSeconds: 60)
        ]
        return day
    }
    static var lowerDay: ProgramDay {
        var day = ProgramSamples.days[1]
        day.exercises = [
            ProgramSamples.squatProgramExercise,
            accessoryExercise(programDayId: day.id, order: 1, sets: 3, repsMin: 8, repsMax: 10, restSeconds: 90),
            accessoryExercise(programDayId: day.id, order: 2, sets: 3, repsMin: 10, repsMax: 12, restSeconds: 75)
        ]
        return day
    }
    static var lastSession: WorkoutSession {
        WorkoutSession(
            id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            userId: ProgramSamples.userId,
            programDayId: ProgramSamples.upperDayId,
            startedAt: Date.now.addingTimeInterval(-2 * 24 * 3600),
            endedAt: Date.now.addingTimeInterval(-2 * 24 * 3600 + 3_000),
            notes: nil,
            createdAt: Date.now.addingTimeInterval(-2 * 24 * 3600)
        )
    }
    static var olderSession: WorkoutSession {
        WorkoutSession(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            userId: ProgramSamples.userId,
            programDayId: ProgramSamples.lowerDayId,
            startedAt: Date.now.addingTimeInterval(-9 * 24 * 3600),
            endedAt: Date.now.addingTimeInterval(-9 * 24 * 3600 + 2_700),
            notes: nil,
            createdAt: Date.now.addingTimeInterval(-9 * 24 * 3600)
        )
    }
    private static func accessoryExercise(programDayId: UUID, order: Int, sets: Int, repsMin: Int, repsMax: Int, restSeconds: Int) -> ProgramExercise {
        ProgramExercise(id: UUID(), programDayId: programDayId, exerciseId: UUID(), targetSets: sets, targetRepsMin: repsMin, targetRepsMax: repsMax, targetRestSeconds: restSeconds, targetWeight: nil, exerciseOrder: order, notes: nil, createdAt: ProgramSamples.createdAt)
    }
}
#endif
