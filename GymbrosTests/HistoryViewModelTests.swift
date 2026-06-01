import Foundation
import Testing
@testable import Gymbros

@MainActor
@Suite("History ViewModels")
struct HistoryViewModelTests {

    // MARK: - HistoryViewModel

    @Test func historyLoadsEmptyStateWhenNoSessions() async throws {
        let workoutRepo = FakeWorkoutRepository(historySessions: [])
        let programRepo = FakeHistoryProgramRepository()
        let vm = HistoryViewModel(workoutRepository: workoutRepo, programRepository: programRepo)

        await vm.load()

        guard case .empty = vm.state else {
            throw AppError.unknown(debugID: "expected-empty")
        }
    }

    @Test func historyLoadsSuccessStateWithSessions() async throws {
        let session = makeSession()
        let workoutRepo = FakeWorkoutRepository(historySessions: [session])
        let programRepo = FakeHistoryProgramRepository()
        let vm = HistoryViewModel(workoutRepository: workoutRepo, programRepository: programRepo)

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.sessions.count == 1)
        #expect(data.sessions[0].id == session.id)
    }

    @Test func historyMapsDayNameForMatchingProgramDayId() async throws {
        let dayId = ProgramSamples.upperDayId
        let session = makeSession(programDayId: dayId)
        let workoutRepo = FakeWorkoutRepository(historySessions: [session])
        let programRepo = FakeHistoryProgramRepository(programs: ProgramSamples.programs)
        let vm = HistoryViewModel(workoutRepository: workoutRepo, programRepository: programRepo)

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.dayNames[dayId] == "Upper A")
    }

    @Test func historyProducesNoDayNameForNilProgramDayId() async throws {
        let session = makeSession(programDayId: nil)
        let workoutRepo = FakeWorkoutRepository(historySessions: [session])
        let programRepo = FakeHistoryProgramRepository(programs: ProgramSamples.programs)
        let vm = HistoryViewModel(workoutRepository: workoutRepo, programRepository: programRepo)

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.dayNames[session.id] == nil)
    }

    @Test func historyProducesNoDayNameForUnknownProgramDayId() async throws {
        let unknownDayId = UUID()
        let session = makeSession(programDayId: unknownDayId)
        let workoutRepo = FakeWorkoutRepository(historySessions: [session])
        let programRepo = FakeHistoryProgramRepository(programs: ProgramSamples.programs)
        let vm = HistoryViewModel(workoutRepository: workoutRepo, programRepository: programRepo)

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.dayNames[unknownDayId] == nil)
    }

    @Test func historyFetchFailureSetsErrorState() async throws {
        let workoutRepo = FakeWorkoutRepository(historySessions: [])
        workoutRepo.fetchHistoryError = AppError.network(.offline)
        let programRepo = FakeHistoryProgramRepository()
        let vm = HistoryViewModel(workoutRepository: workoutRepo, programRepository: programRepo)

        await vm.load()

        guard case .error(let error) = vm.state else {
            throw AppError.unknown(debugID: "expected-error")
        }
        #expect(error == .network(.offline))
    }

    @Test func deleteSessionRemovesRowFromSuccessState() async throws {
        let firstSession = makeSession()
        let secondSession = makeSession()
        let workoutRepo = FakeWorkoutRepository(historySessions: [firstSession, secondSession])
        let programRepo = FakeHistoryProgramRepository()
        let vm = HistoryViewModel(workoutRepository: workoutRepo, programRepository: programRepo)

        await vm.load()
        await vm.deleteSession(firstSession)

        let data = try successValue(vm.state)
        #expect(workoutRepo.deletedSessionIds == [firstSession.id])
        #expect(data.sessions.map(\.id) == [secondSession.id])
    }

    @Test func deleteOnlySessionShowsEmptyState() async throws {
        let session = makeSession()
        let workoutRepo = FakeWorkoutRepository(historySessions: [session])
        let programRepo = FakeHistoryProgramRepository()
        let vm = HistoryViewModel(workoutRepository: workoutRepo, programRepository: programRepo)

        await vm.load()
        await vm.deleteSession(session)

        #expect(workoutRepo.deletedSessionIds == [session.id])
        guard case .empty = vm.state else {
            throw AppError.unknown(debugID: "expected-empty-after-delete")
        }
    }

    @Test func deleteSessionFailureKeepsRowsAndSetsTransientError() async throws {
        let session = makeSession()
        let workoutRepo = FakeWorkoutRepository(historySessions: [session])
        workoutRepo.deleteSessionError = AppError.network(.offline)
        let programRepo = FakeHistoryProgramRepository()
        let vm = HistoryViewModel(workoutRepository: workoutRepo, programRepository: programRepo)

        await vm.load()
        await vm.deleteSession(session)

        let data = try successValue(vm.state)
        #expect(data.sessions.map(\.id) == [session.id])
        #expect(vm.transientError == .network(.offline))
    }

    // MARK: - SessionDetailViewModel

    @Test func sessionDetailLoadsSuccessWithEmptySets() async throws {
        let session = makeSession()
        let workoutRepo = FakeWorkoutRepository(historySessions: [session], sets: [])
        let exerciseRepo = FakeHistoryExerciseRepository()
        let vm = SessionDetailViewModel(session: session, workoutRepository: workoutRepo, exerciseRepository: exerciseRepo)

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.sets.isEmpty)
        #expect(data.session.id == session.id)
    }

    @Test func sessionDetailLoadsSuccessWithSets() async throws {
        let session = makeSession()
        let set1 = makeSet(sessionId: session.id, setNumber: 1)
        let set2 = makeSet(sessionId: session.id, setNumber: 2)
        let workoutRepo = FakeWorkoutRepository(sets: [set1, set2])
        let exerciseRepo = FakeHistoryExerciseRepository()
        let vm = SessionDetailViewModel(session: session, workoutRepository: workoutRepo, exerciseRepository: exerciseRepo)

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.sets.count == 2)
    }

    @Test func sessionDetailFetchSetsFailureSetsErrorState() async throws {
        let session = makeSession()
        let workoutRepo = FakeWorkoutRepository(historySessions: [session], sets: [])
        workoutRepo.fetchSetsError = AppError.network(.offline)
        let exerciseRepo = FakeHistoryExerciseRepository()
        let vm = SessionDetailViewModel(session: session, workoutRepository: workoutRepo, exerciseRepository: exerciseRepo)

        await vm.load()

        guard case .error(let error) = vm.state else {
            throw AppError.unknown(debugID: "expected-error")
        }
        #expect(error == .network(.offline))
    }

    @Test func sessionDetailExerciseFetchFailureProducesEmptyLookupButSuccess() async throws {
        let session = makeSession()
        let set1 = makeSet(sessionId: session.id)
        let workoutRepo = FakeWorkoutRepository(sets: [set1])
        let exerciseRepo = FakeHistoryExerciseRepository()
        exerciseRepo.fetchAllError = AppError.network(.offline)
        let vm = SessionDetailViewModel(session: session, workoutRepository: workoutRepo, exerciseRepository: exerciseRepo)

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.sets.count == 1)
        #expect(data.exerciseLookup.isEmpty)
    }

    @Test func sessionDetailUpdateDurationAdjustsEndedAt() async throws {
        let session = makeSession()
        let workoutRepo = FakeWorkoutRepository(sets: [])
        let exerciseRepo = FakeHistoryExerciseRepository()
        let vm = SessionDetailViewModel(session: session, workoutRepository: workoutRepo, exerciseRepository: exerciseRepo)

        await vm.load()
        await vm.updateDuration(minutes: 45)

        let data = try successValue(vm.state)
        #expect(data.session.endedAt == session.startedAt.addingTimeInterval(45 * 60))
        #expect(vm.isEditingDuration == false)
    }

    // MARK: - Helpers

    private func successValue<T>(_ state: ViewState<T>) throws -> T {
        guard case let .success(value) = state else {
            throw AppError.unknown(debugID: "expected-success")
        }
        return value
    }

    private func makeSession(programDayId: UUID? = nil) -> WorkoutSession {
        WorkoutSession(
            id: UUID(),
            userId: ProgramSamples.userId,
            programDayId: programDayId,
            startedAt: Date(timeIntervalSince1970: 1_778_342_400),
            endedAt: Date(timeIntervalSince1970: 1_778_346_000),
            notes: nil,
            createdAt: Date(timeIntervalSince1970: 1_778_342_400)
        )
    }

    private func makeSet(sessionId: UUID = UUID(), setNumber: Int = 1) -> WorkoutSet {
        WorkoutSet(
            id: UUID(),
            sessionId: sessionId,
            exerciseId: ProgramSamples.benchExerciseId,
            programExerciseId: nil,
            setNumber: setNumber,
            weight: 60.0,
            reps: 10,
            rpe: nil,
            targetRestSeconds: nil,
            actualRestSeconds: nil,
            restStartedAt: nil,
            restEndedAt: nil,
            completedAt: Date(timeIntervalSince1970: 1_778_342_400),
            notes: nil
        )
    }
}

@MainActor
private final class FakeWorkoutRepository: WorkoutRepositoryProviding {
    var historySessions: [WorkoutSession]
    var sets: [WorkoutSet]
    var fetchHistoryError: AppError?
    var fetchSetsError: AppError?
    var deleteSessionError: AppError?
    var deletedSessionIds: [UUID] = []

    init(historySessions: [WorkoutSession] = [], sets: [WorkoutSet] = []) {
        self.historySessions = historySessions
        self.sets = sets
    }

    func fetchHistory(limit: Int) async throws -> [WorkoutSession] {
        if let fetchHistoryError { throw fetchHistoryError }
        return historySessions
    }

    func fetchSets(sessionId: UUID) async throws -> [WorkoutSet] {
        if let fetchSetsError { throw fetchSetsError }
        return sets
    }

    func createSession(programDayId: UUID, startedAt: Date) async throws -> WorkoutSession {
        fatalError("not used in history tests")
    }

    func uploadSet(_ set: WorkoutSet) async throws -> WorkoutSet { set }
    func updateSet(_ set: WorkoutSet) async throws -> WorkoutSet { set }
    func deleteSet(id: UUID) async throws {}
    func deleteSession(id: UUID) async throws {
        if let deleteSessionError { throw deleteSessionError }
        deletedSessionIds.append(id)
    }
    func completeSession(_ sessionId: UUID, endedAt: Date) async throws {}
    func updateSessionEndedAt(sessionId: UUID, endedAt: Date) async throws -> WorkoutSession {
        var session = historySessions.first ?? WorkoutSession(
            id: sessionId,
            userId: ProgramSamples.userId,
            programDayId: nil,
            startedAt: endedAt.addingTimeInterval(-3600),
            endedAt: endedAt,
            notes: nil,
            createdAt: endedAt.addingTimeInterval(-3600)
        )
        session.endedAt = endedAt
        return session
    }
    func fetchLastLoggedSet(exerciseId: UUID, before: Date) async throws -> WorkoutSet? { nil }
}

@MainActor
private final class FakeHistoryProgramRepository: ProgramRepositoryProviding {
    var programs: [Program]
    var fetchAllError: AppError?

    init(programs: [Program] = []) {
        self.programs = programs
    }

    func fetchAll() async throws -> [Program] {
        if let fetchAllError { throw fetchAllError }
        return programs
    }

    func fetchFull(id: UUID) async throws -> Program { ProgramSamples.program }
    func fetchDay(id: UUID) async throws -> ProgramDay { ProgramSamples.days[0] }
    func fetchProgramExercises(dayId: UUID) async throws -> [ProgramExercise] { [] }
    func fetchActive() async throws -> Program? { nil }
    func createProgram(name: String, description: String?) async throws -> Program { ProgramSamples.program }
    func updateProgramMetadata(id: UUID, name: String, description: String?) async throws -> Program { ProgramSamples.program }
    func delete(id: UUID) async throws {}
    func setActive(programId: UUID) async throws {}
    func createDay(programId: UUID, name: String, order: Int) async throws -> ProgramDay { ProgramSamples.days[0] }
    func updateDay(id: UUID, name: String, order: Int) async throws -> ProgramDay { ProgramSamples.days[0] }
    func deleteDay(id: UUID) async throws {}
    func reorderDays(_ days: [ProgramDay]) async throws {}
    func createProgramExercise(
        dayId: UUID,
        exerciseId: UUID,
        targetSets: Int,
        targetRepsMin: Int,
        targetRepsMax: Int,
        targetRestSeconds: Int,
        targetWeight: Double?,
        order: Int,
        notes: String?
    ) async throws -> ProgramExercise { ProgramSamples.benchProgramExercise }
    func updateProgramExercise(_ programExercise: ProgramExercise) async throws -> ProgramExercise { programExercise }
    func deleteProgramExercise(id: UUID) async throws {}
    func reorderProgramExercises(_ exercises: [ProgramExercise]) async throws {}
}

@MainActor
private final class FakeHistoryExerciseRepository: ExerciseRepositoryProviding {
    var exercises: [Exercise]
    var fetchAllError: AppError?

    init(exercises: [Exercise] = ProgramSamples.exercises) {
        self.exercises = exercises
    }

    func fetchAll() async throws -> [Exercise] {
        if let fetchAllError { throw fetchAllError }
        return exercises
    }
}
