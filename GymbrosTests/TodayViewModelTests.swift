import Foundation
import Testing
@testable import Gymbros

@MainActor
@Suite("TodayViewModel")
struct TodayViewModelTests {

    // MARK: - No active program

    @Test func noActiveProgram_successWithNilNextDay() async throws {
        let programRepo = FakeTodayProgramRepository(active: nil)
        let vm = TodayViewModel(programRepository: programRepo, workoutRepository: FakeTodayWorkoutRepository())

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.activeProgram == nil)
        #expect(data.nextDay == nil)
    }

    // MARK: - Next-day derivation

    @Test func activeProgramNoHistory_nextDayIsFirstDay() async throws {
        let program = makeTodayProgram()
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: FakeTodayWorkoutRepository(history: [])
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.nextDay?.id == TodaySamples.day1Id)
    }

    @Test func activeProgramOneSession_nextDayWrapsCorrectly() async throws {
        let program = makeTodayProgram()
        // Last session was on day1 → next should be day2
        let session = makeSession(programDayId: TodaySamples.day1Id, daysAgo: 2)
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: FakeTodayWorkoutRepository(history: [session])
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.nextDay?.id == TodaySamples.day2Id)
    }

    @Test func activeProgramLastDayCompleted_nextDayWrapsToFirst() async throws {
        let program = makeTodayProgram()
        // Last session was on day2 → wraps to day1
        let session = makeSession(programDayId: TodaySamples.day2Id, daysAgo: 2)
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: FakeTodayWorkoutRepository(history: [session])
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.nextDay?.id == TodaySamples.day1Id)
    }

    @Test func sessionWithNilProgramDayId_nextDayFallsBackToFirst() async throws {
        let program = makeTodayProgram()
        let session = makeSession(programDayId: nil, daysAgo: 1)
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: FakeTodayWorkoutRepository(history: [session])
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.nextDay?.id == TodaySamples.day1Id)
    }

    @Test func sessionWithStaleProgramDayId_nextDayFallsBackToFirst() async throws {
        let program = makeTodayProgram()
        let unknownDayId = UUID()
        let session = makeSession(programDayId: unknownDayId, daysAgo: 1)
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: FakeTodayWorkoutRepository(history: [session])
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.nextDay?.id == TodaySamples.day1Id)
    }

    // MARK: - isWelcomeBack

    @Test func lastSessionMoreThan7DaysAgo_isWelcomeBack() async throws {
        let program = makeTodayProgram()
        let session = makeSession(programDayId: TodaySamples.day1Id, daysAgo: 8)
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: FakeTodayWorkoutRepository(history: [session])
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.isWelcomeBack == true)
    }

    @Test func lastSessionWithin7Days_notWelcomeBack() async throws {
        let program = makeTodayProgram()
        let session = makeSession(programDayId: TodaySamples.day1Id, daysAgo: 3)
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: FakeTodayWorkoutRepository(history: [session])
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.isWelcomeBack == false)
    }

    @Test func noHistoryWithActiveProgram_isWelcomeBack() async throws {
        let program = makeTodayProgram()
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: FakeTodayWorkoutRepository(history: [])
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.isWelcomeBack == true)
    }

    // MARK: - Comeback recommendation

    @Test func fifteenDayOldHistory_recommendationIsComebackFirstBand() async throws {
        let program = makeTodayProgram(withExercises: true)
        let session = makeSession(programDayId: TodaySamples.day1Id, daysAgo: 15)
        let workoutRepo = FakeTodayWorkoutRepository(history: [session])
        workoutRepo.setsBySessionId[session.id] = [makeSet(sessionId: session.id, weight: 80, reps: 8)]
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: workoutRepo
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.recommendation.mode.isComeback)
        #expect(data.recommendation.stage?.bandKey == "comeback.band.14_20")
        #expect(data.recommendation.stage?.weightMultiplier == 0.9)
        let adjustment = try #require(data.recommendation.adjustments[TodaySamples.programExerciseId])
        #expect(adjustment.adjustedTargetWeight == 80 * 0.9)
    }

    @Test func recentHistory_recommendationIsNormal() async throws {
        let program = makeTodayProgram(withExercises: true)
        let session = makeSession(programDayId: TodaySamples.day1Id, daysAgo: 3)
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: FakeTodayWorkoutRepository(history: [session])
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.recommendation.mode == .normal)
    }

    @Test func trackComebackCardShown_forwardsToAnalytics() {
        let spy = SpyAnalytics()
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(),
            workoutRepository: FakeTodayWorkoutRepository(),
            analytics: spy
        )

        vm.trackComebackCardShown()

        #expect(spy.events == [.comebackCardShown])
    }

    // MARK: - Progressive Overload Advisor

    private func makeExercise() -> Exercise {
        Exercise(
            id: TodaySamples.exerciseId,
            ownerUserId: nil,
            slug: "bench_press",
            name: "Bench Press",
            movementPattern: .push,
            primaryMuscle: .chest,
            secondaryMuscles: [],
            equipment: .barbell,
            isCompound: true,
            createdAt: TodaySamples.baseDate
        )
    }

    private func makeTodayProfile(trainingPhase: TrainingPhase?) -> Profile {
        Profile(
            id: TodaySamples.userId,
            email: nil,
            name: nil,
            experienceLevel: nil,
            goal: nil,
            trainingPhase: trainingPhase,
            daysPerWeek: nil,
            weightUnit: .kg,
            locale: "en",
            createdAt: TodaySamples.baseDate,
            updatedAt: TodaySamples.baseDate
        )
    }

    @Test func stalledExerciseAppearsInNormalModeAfterFourSessions() async throws {
        let program = makeTodayProgram(withExercises: true)
        // Last session on day2 so nextDay wraps to day1, which owns the exercise.
        let sessions = [1, 3, 5, 7].map { makeSession(programDayId: TodaySamples.day2Id, daysAgo: Double($0)) }
        let workoutRepo = FakeTodayWorkoutRepository(history: sessions)
        for session in sessions {
            workoutRepo.setsBySessionId[session.id] = [makeSet(sessionId: session.id, weight: 80, reps: 8, rpe: 7.0)]
        }
        let exerciseRepo = FakeTodayExerciseRepository()
        exerciseRepo.exercises = [makeExercise()]
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: workoutRepo,
            exerciseRepository: exerciseRepo,
            overloadSnoozeStore: FakeOverloadSnoozeStore()
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.recommendation.mode == .normal)
        let stalled = try #require(data.stalledExercise)
        #expect(stalled.programExercise.id == TodaySamples.programExerciseId)
        #expect(stalled.exerciseName == "Bench Press")
        #expect(stalled.weight == 80)
    }

    @Test func stalledExerciseDetectedAcrossInterleavedMultiDayRotation() async throws {
        let program = makeTodayProgram(withExercises: true)
        // Exercise lives only on day1. Alternate day2/day1 so day1 sessions are interleaved,
        // not consecutive -- this is what a real 2-day split's history looks like. Most
        // recent session is day2, so nextDay wraps to day1 (which owns the exercise).
        let day1Sessions = [2, 4, 6, 8].map { makeSession(programDayId: TodaySamples.day1Id, daysAgo: Double($0)) }
        let day2Sessions = [1, 3, 5, 7].map { makeSession(programDayId: TodaySamples.day2Id, daysAgo: Double($0)) }
        let workoutRepo = FakeTodayWorkoutRepository(history: day1Sessions + day2Sessions)
        for session in day1Sessions {
            workoutRepo.setsBySessionId[session.id] = [makeSet(sessionId: session.id, weight: 80, reps: 8, rpe: 7.0)]
        }
        let exerciseRepo = FakeTodayExerciseRepository()
        exerciseRepo.exercises = [makeExercise()]
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: workoutRepo,
            exerciseRepository: exerciseRepo,
            overloadSnoozeStore: FakeOverloadSnoozeStore()
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.recommendation.mode == .normal)
        let stalled = try #require(data.stalledExercise)
        #expect(stalled.programExercise.id == TodaySamples.programExerciseId)
        #expect(stalled.weight == 80)
    }

    @Test func stalledExerciseSuppressedWhenTrainingPhaseIsCut() async throws {
        let program = makeTodayProgram(withExercises: true)
        let sessions = [1, 3, 5, 7].map { makeSession(programDayId: TodaySamples.day2Id, daysAgo: Double($0)) }
        let workoutRepo = FakeTodayWorkoutRepository(history: sessions)
        for session in sessions {
            workoutRepo.setsBySessionId[session.id] = [makeSet(sessionId: session.id, weight: 80, reps: 8, rpe: 7.0)]
        }
        let exerciseRepo = FakeTodayExerciseRepository()
        exerciseRepo.exercises = [makeExercise()]
        let profileRepo = FakeTodayProfileRepository()
        profileRepo.profile = makeTodayProfile(trainingPhase: .cut)
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: workoutRepo,
            exerciseRepository: exerciseRepo,
            profileRepository: profileRepo,
            overloadSnoozeStore: FakeOverloadSnoozeStore()
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.trainingPhase == .cut)
        #expect(data.stalledExercise == nil)
    }

    @Test func stalledExerciseNeverShownAlongsideComebackMode() async throws {
        let program = makeTodayProgram(withExercises: true)
        // All 4 sessions are >=14 days old and identical weight: would be a stall in
        // normal mode, but the whole history being that old also triggers comeback.
        let sessions = [20, 22, 24, 26].map { makeSession(programDayId: TodaySamples.day1Id, daysAgo: Double($0)) }
        let workoutRepo = FakeTodayWorkoutRepository(history: sessions)
        for session in sessions {
            workoutRepo.setsBySessionId[session.id] = [makeSet(sessionId: session.id, weight: 80, reps: 8, rpe: 7.0)]
        }
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: workoutRepo,
            exerciseRepository: FakeTodayExerciseRepository(),
            profileRepository: FakeTodayProfileRepository(),
            overloadSnoozeStore: FakeOverloadSnoozeStore()
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.recommendation.mode.isComeback)
        #expect(data.stalledExercise == nil)
    }

    @Test func tryOverloadSuggestionUpdatesTargetWeightAndClearsCard() async throws {
        let program = makeTodayProgram(withExercises: true)
        let sessions = [1, 3, 5, 7].map { makeSession(programDayId: TodaySamples.day2Id, daysAgo: Double($0)) }
        let workoutRepo = FakeTodayWorkoutRepository(history: sessions)
        for session in sessions {
            workoutRepo.setsBySessionId[session.id] = [makeSet(sessionId: session.id, weight: 80, reps: 8, rpe: 7.0)]
        }
        let exerciseRepo = FakeTodayExerciseRepository()
        exerciseRepo.exercises = [makeExercise()]
        let programRepo = FakeTodayProgramRepository(active: program)
        let suggestionTracker = FakeOverloadSuggestionTracker()
        let vm = TodayViewModel(
            programRepository: programRepo,
            workoutRepository: workoutRepo,
            exerciseRepository: exerciseRepo,
            overloadSnoozeStore: FakeOverloadSnoozeStore(),
            overloadSuggestionTracker: suggestionTracker
        )

        await vm.load()
        let stalled = try #require(try successValue(vm.state).stalledExercise)
        await vm.tryOverloadSuggestion(stalled)

        #expect(programRepo.updatedProgramExercise?.targetWeight == 82.5)
        #expect(try successValue(vm.state).stalledExercise == nil)
        #expect(suggestionTracker.recordedPreviousWeights[TodaySamples.programExerciseId] == 80)
    }

    @Test func snoozeOverloadSuggestionHidesCardAndPersists() async throws {
        let program = makeTodayProgram(withExercises: true)
        let sessions = [1, 3, 5, 7].map { makeSession(programDayId: TodaySamples.day2Id, daysAgo: Double($0)) }
        let workoutRepo = FakeTodayWorkoutRepository(history: sessions)
        for session in sessions {
            workoutRepo.setsBySessionId[session.id] = [makeSet(sessionId: session.id, weight: 80, reps: 8, rpe: 7.0)]
        }
        let exerciseRepo = FakeTodayExerciseRepository()
        exerciseRepo.exercises = [makeExercise()]
        let snoozeStore = FakeOverloadSnoozeStore()
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: workoutRepo,
            exerciseRepository: exerciseRepo,
            overloadSnoozeStore: snoozeStore
        )

        await vm.load()
        let stalled = try #require(try successValue(vm.state).stalledExercise)
        vm.snoozeOverloadSuggestion(stalled)

        #expect(try successValue(vm.state).stalledExercise == nil)
        #expect(snoozeStore.snoozed.contains(TodaySamples.programExerciseId))
    }

    // MARK: - Error handling

    @Test func repositoryError_stateIsError() async {
        let workoutRepo = FakeTodayWorkoutRepository()
        workoutRepo.fetchHistoryError = .network(.offline)
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: makeTodayProgram()),
            workoutRepository: workoutRepo
        )

        await vm.load()

        guard case .error(let error) = vm.state else {
            Issue.record("Expected .error state")
            return
        }
        #expect(error == .network(.offline))
    }
}

// MARK: - Helpers

private func successValue<T>(_ state: ViewState<T>) throws -> T {
    guard case .success(let value) = state else {
        throw AppError.unknown(debugID: "expected-success-state")
    }
    return value
}

private func makeTodayProgram(withExercises: Bool = false) -> Program {
    var p = Program(
        id: TodaySamples.programId,
        userId: TodaySamples.userId,
        name: "Test Program",
        description: nil,
        isActive: true,
        createdAt: TodaySamples.baseDate,
        updatedAt: TodaySamples.baseDate
    )
    var day1 = ProgramDay(id: TodaySamples.day1Id, programId: TodaySamples.programId, name: "Day A", dayOrder: 0, createdAt: TodaySamples.baseDate)
    if withExercises {
        day1.exercises = [
            ProgramExercise(
                id: TodaySamples.programExerciseId,
                programDayId: TodaySamples.day1Id,
                exerciseId: TodaySamples.exerciseId,
                targetSets: 3,
                targetRepsMin: 8,
                targetRepsMax: 10,
                targetRestSeconds: 90,
                targetWeight: nil,
                exerciseOrder: 0,
                notes: nil,
                createdAt: TodaySamples.baseDate
            )
        ]
    }
    p.days = [
        day1,
        ProgramDay(id: TodaySamples.day2Id, programId: TodaySamples.programId, name: "Day B", dayOrder: 1, createdAt: TodaySamples.baseDate)
    ]
    return p
}

private func makeSet(sessionId: UUID, weight: Double, reps: Int, rpe: Double? = nil) -> WorkoutSet {
    WorkoutSet(
        id: UUID(),
        sessionId: sessionId,
        exerciseId: TodaySamples.exerciseId,
        programExerciseId: TodaySamples.programExerciseId,
        setNumber: 1,
        weight: weight,
        reps: reps,
        rpe: rpe,
        targetRestSeconds: nil,
        actualRestSeconds: nil,
        restStartedAt: nil,
        restEndedAt: nil,
        completedAt: Date.now,
        notes: nil
    )
}

private final class SpyAnalytics: AnalyticsTracking {
    var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
}

private func makeSession(programDayId: UUID?, daysAgo: Double) -> WorkoutSession {
    let start = Date.now.addingTimeInterval(-daysAgo * 86_400)
    return WorkoutSession(
        id: UUID(),
        userId: TodaySamples.userId,
        programDayId: programDayId,
        startedAt: start,
        endedAt: start.addingTimeInterval(3600),
        notes: nil,
        createdAt: start
    )
}

// MARK: - Test Samples

private enum TodaySamples {
    static let userId = UUID(uuidString: "aaaa0000-0000-0000-0000-000000000000")!
    static let programId = UUID(uuidString: "bbbb0000-0000-0000-0000-000000000000")!
    static let day1Id = UUID(uuidString: "cccc0000-0000-0000-0000-000000000000")!
    static let day2Id = UUID(uuidString: "dddd0000-0000-0000-0000-000000000000")!
    static let programExerciseId = UUID(uuidString: "eeee0000-0000-0000-0000-000000000000")!
    static let exerciseId = UUID(uuidString: "ffff0000-0000-0000-0000-000000000000")!
    static let baseDate = Date(timeIntervalSince1970: 1_778_342_400)
}

// MARK: - Fakes

@MainActor
private final class FakeTodayProgramRepository: ProgramRepositoryProviding {
    var active: Program?
    var fetchActiveError: AppError?

    init(active: Program? = nil) {
        self.active = active
    }

    func fetchActive() async throws -> Program? {
        if let fetchActiveError { throw fetchActiveError }
        return active
    }

    func fetchAll() async throws -> [Program] { active.map { [$0] } ?? [] }
    func fetchFull(id: UUID) async throws -> Program { throw AppError.notFound }
    func fetchDay(id: UUID) async throws -> ProgramDay { throw AppError.notFound }
    func fetchProgramExercises(dayId: UUID) async throws -> [ProgramExercise] { [] }
    func createProgram(name: String, description: String?) async throws -> Program { throw AppError.notFound }
    func updateProgramMetadata(id: UUID, name: String, description: String?) async throws -> Program { throw AppError.notFound }
    func delete(id: UUID) async throws {}
    func setActive(programId: UUID) async throws {}
    func createDay(programId: UUID, name: String, order: Int) async throws -> ProgramDay { throw AppError.notFound }
    func updateDay(id: UUID, name: String, order: Int) async throws -> ProgramDay { throw AppError.notFound }
    func deleteDay(id: UUID) async throws {}
    func reorderDays(_ days: [ProgramDay]) async throws {}
    func createProgramExercise(dayId: UUID, exerciseId: UUID, targetSets: Int, targetRepsMin: Int, targetRepsMax: Int, targetRestSeconds: Int, targetWeight: Double?, order: Int, notes: String?) async throws -> ProgramExercise { throw AppError.notFound }

    var updatedProgramExercise: ProgramExercise?
    func updateProgramExercise(_ programExercise: ProgramExercise) async throws -> ProgramExercise {
        updatedProgramExercise = programExercise
        return programExercise
    }
    func deleteProgramExercise(id: UUID) async throws {}
    func reorderProgramExercises(_ exercises: [ProgramExercise]) async throws {}
}

@MainActor
private final class FakeTodayProfileRepository: ProfileRepositoryProviding {
    var profile: Profile?
    func fetchCurrentProfile() async throws -> Profile {
        guard let profile else { throw AppError.notFound }
        return profile
    }
    func updateProfile(_ profile: Profile) async throws {}
}

@MainActor
private final class FakeTodayExerciseRepository: ExerciseRepositoryProviding {
    var exercises: [Exercise] = []
    func fetchAll() async throws -> [Exercise] { exercises }
}

@MainActor
private final class FakeOverloadSnoozeStore: OverloadAdvisorSnoozing {
    var snoozed: Set<UUID> = []
    func isSnoozed(programExerciseId: UUID, now: Date) -> Bool { snoozed.contains(programExerciseId) }
    func snooze(programExerciseId: UUID, now: Date) { snoozed.insert(programExerciseId) }
}

@MainActor
private final class FakeOverloadSuggestionTracker: OverloadSuggestionTracking {
    var recordedPreviousWeights: [UUID: Double] = [:]
    func pendingPreviousWeight(programExerciseId: UUID) -> Double? { recordedPreviousWeights[programExerciseId] }
    func recordSuggestion(programExerciseId: UUID, previousWeight: Double) {
        recordedPreviousWeights[programExerciseId] = previousWeight
    }
    func clearSuggestion(programExerciseId: UUID) { recordedPreviousWeights.removeValue(forKey: programExerciseId) }
}

@MainActor
private final class FakeTodayWorkoutRepository: WorkoutRepositoryProviding {
    var history: [WorkoutSession]
    var setsBySessionId: [UUID: [WorkoutSet]] = [:]
    var fetchHistoryError: AppError?

    init(history: [WorkoutSession] = []) {
        self.history = history
    }

    func fetchHistory(limit: Int) async throws -> [WorkoutSession] {
        if let fetchHistoryError { throw fetchHistoryError }
        return history
    }

    func insertSession(_ session: WorkoutSession) async throws { throw AppError.notFound }
    func uploadSet(_ set: WorkoutSet) async throws -> WorkoutSet { throw AppError.notFound }
    func updateSet(_ set: WorkoutSet) async throws -> WorkoutSet { throw AppError.notFound }
    func updateSets(ids: [UUID], rpe: Double) async throws {}
    func deleteSet(id: UUID) async throws {}
    func deleteSession(id: UUID) async throws {}
    func completeSession(_ sessionId: UUID, endedAt: Date) async throws {}
    func updateSessionEndedAt(sessionId: UUID, endedAt: Date) async throws -> WorkoutSession {
        throw AppError.notFound
    }
    func fetchSets(sessionId: UUID) async throws -> [WorkoutSet] { setsBySessionId[sessionId] ?? [] }
    func fetchLastLoggedSet(exerciseId: UUID, before: Date) async throws -> WorkoutSet? { nil }
}
