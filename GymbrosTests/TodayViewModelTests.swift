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

private func makeTodayProgram() -> Program {
    var p = Program(
        id: TodaySamples.programId,
        userId: TodaySamples.userId,
        name: "Test Program",
        description: nil,
        isActive: true,
        createdAt: TodaySamples.baseDate,
        updatedAt: TodaySamples.baseDate
    )
    p.days = [
        ProgramDay(id: TodaySamples.day1Id, programId: TodaySamples.programId, name: "Day A", dayOrder: 0, createdAt: TodaySamples.baseDate),
        ProgramDay(id: TodaySamples.day2Id, programId: TodaySamples.programId, name: "Day B", dayOrder: 1, createdAt: TodaySamples.baseDate)
    ]
    return p
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
    func updateProgramExercise(_ programExercise: ProgramExercise) async throws -> ProgramExercise { throw AppError.notFound }
    func deleteProgramExercise(id: UUID) async throws {}
    func reorderProgramExercises(_ exercises: [ProgramExercise]) async throws {}
}

@MainActor
private final class FakeTodayWorkoutRepository: WorkoutRepositoryProviding {
    var history: [WorkoutSession]
    var fetchHistoryError: AppError?

    init(history: [WorkoutSession] = []) {
        self.history = history
    }

    func fetchHistory(limit: Int) async throws -> [WorkoutSession] {
        if let fetchHistoryError { throw fetchHistoryError }
        return history
    }

    func createSession(programDayId: UUID, startedAt: Date) async throws -> WorkoutSession { throw AppError.notFound }
    func uploadSet(_ set: WorkoutSet) async throws -> WorkoutSet { throw AppError.notFound }
    func updateSet(_ set: WorkoutSet) async throws -> WorkoutSet { throw AppError.notFound }
    func deleteSet(id: UUID) async throws {}
    func deleteSession(id: UUID) async throws {}
    func completeSession(_ sessionId: UUID, endedAt: Date) async throws {}
    func updateSessionEndedAt(sessionId: UUID, endedAt: Date) async throws -> WorkoutSession {
        throw AppError.notFound
    }
    func fetchSets(sessionId: UUID) async throws -> [WorkoutSet] { return [] }
    func fetchLastLoggedSet(exerciseId: UUID, before: Date) async throws -> WorkoutSet? { nil }
}
