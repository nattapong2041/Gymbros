import Foundation
import Testing
@testable import Gymbros

@MainActor
@Suite("Workout Session ViewModel")
struct WorkoutSessionViewModelTests {
    @Test func startSuccessCreatesSessionAndInitialRows() async throws {
        let workoutRepository = FakeWorkoutRepository()
        let viewModel = makeViewModel(workoutRepository: workoutRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)

        let data = try successValue(viewModel.state)
        #expect(workoutRepository.createdSessions.map(\.programDayId) == [ProgramSamples.upperDayId])
        #expect(data.exerciseSections.count == 1)
        #expect(data.exerciseSections[0].sets.count == ProgramSamples.benchProgramExercise.targetSets)
        #expect(data.exerciseSections[0].sets.map(\.repsText) == ["8", "8", "8"])
    }

    @Test func invalidSetValidationAvoidsUpload() async throws {
        let workoutRepository = FakeWorkoutRepository()
        let viewModel = makeViewModel(workoutRepository: workoutRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "-1", repsText: "8", rpe: 7)
        await viewModel.completeSet(setId: row.id)

        #expect(viewModel.transientError == .validation(.invalidInput))
        #expect(workoutRepository.uploadedSets.isEmpty)
    }

    @Test func addSetCopiesPreviousValuesAndRenumbers() async throws {
        let viewModel = makeViewModel()

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "82.5", repsText: "9", rpe: 8)
        await viewModel.addSet(after: row.id)

        let sets = try successValue(viewModel.state).exerciseSections[0].sets
        let added = try #require(sets.last)
        #expect(sets.map(\.setNumber) == [1, 2, 3, 4])
        #expect(added.weightText == "82.5")
        #expect(added.repsText == "9")
        #expect(added.rpe == 8)
    }

    @Test func deleteSetRenumbersRemainingRows() async throws {
        let viewModel = makeViewModel()

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let secondRow = try successValue(viewModel.state).exerciseSections[0].sets[1]
        await viewModel.deleteSet(setId: secondRow.id)

        let sets = try successValue(viewModel.state).exerciseSections[0].sets
        #expect(sets.count == 2)
        #expect(sets.map(\.setNumber) == [1, 2])
    }

    @Test func uploadFailureCanBeRetried() async throws {
        let workoutRepository = FakeWorkoutRepository()
        workoutRepository.nextUploadError = .network(.offline)
        let viewModel = makeViewModel(workoutRepository: workoutRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "80", repsText: "8", rpe: 7.5)
        await viewModel.completeSet(setId: row.id)

        guard case .failed(.network(.offline)) = try rowState(viewModel, id: row.id).syncState else {
            throw AppError.unknown(debugID: "expected-upload-failure")
        }

        await viewModel.retryUpload(setId: row.id)

        #expect(try rowState(viewModel, id: row.id).syncState == .uploaded)
        #expect(workoutRepository.uploadedSets.count == 2)
    }

    @Test func finishDoesNotClearBackupWhenCompletionFails() async throws {
        let workoutRepository = FakeWorkoutRepository()
        let backupRepository = FakeBackupRepository()
        let viewModel = makeViewModel(workoutRepository: workoutRepository, backupRepository: backupRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "80", repsText: "8", rpe: nil)
        await viewModel.completeSet(setId: row.id)
        workoutRepository.completeSessionError = .network(.offline)
        await viewModel.finishSession()

        #expect(backupRepository.clearCount == 0)
        #expect(backupRepository.savedSnapshots.isEmpty == false)
        #expect(viewModel.transientError == .network(.offline))
    }

    @Test func finishClearsBackupWhenCompletionSucceeds() async throws {
        let workoutRepository = FakeWorkoutRepository()
        let backupRepository = FakeBackupRepository()
        let viewModel = makeViewModel(workoutRepository: workoutRepository, backupRepository: backupRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "80", repsText: "8", rpe: nil)
        await viewModel.completeSet(setId: row.id)
        await viewModel.finishSession()

        #expect(backupRepository.clearCount == 1)
        #expect(workoutRepository.completedSessions.map(\.sessionId) == [workoutRepository.session.id])
    }

    @Test func timerRemainingUsesDates() {
        let startedAt = ProgramSamples.createdAt
        let timer = RestTimerState(
            sourceSetId: UUID(),
            targetSeconds: 90,
            startedAt: startedAt,
            endsAt: startedAt.addingTimeInterval(90)
        )

        #expect(timer.remainingSeconds(at: startedAt.addingTimeInterval(10)) == 80)
        #expect(timer.remainingSeconds(at: startedAt.addingTimeInterval(91)) == 0)
    }

    private func makeViewModel(
        workoutRepository: FakeWorkoutRepository? = nil,
        backupRepository: FakeBackupRepository? = nil
    ) -> WorkoutSessionViewModel {
        WorkoutSessionViewModel(
            workoutRepository: workoutRepository ?? FakeWorkoutRepository(),
            programRepository: FakeWorkoutProgramRepository(),
            exerciseRepository: FakeWorkoutExerciseRepository(),
            backupRepository: backupRepository ?? FakeBackupRepository(),
            now: { ProgramSamples.createdAt }
        )
    }

    private func successValue<T>(_ state: ViewState<T>) throws -> T {
        guard case let .success(value) = state else {
            throw AppError.unknown(debugID: "expected-success")
        }
        return value
    }

    private func firstRow(_ viewModel: WorkoutSessionViewModel) throws -> WorkoutSetRowState {
        try #require(successValue(viewModel.state).exerciseSections.first?.sets.first)
    }

    private func rowState(_ viewModel: WorkoutSessionViewModel, id: UUID) throws -> WorkoutSetRowState {
        try #require(successValue(viewModel.state).exerciseSections.flatMap(\.sets).first { $0.id == id })
    }
}

@MainActor
private final class FakeWorkoutRepository: WorkoutRepositoryProviding {
    var session = WorkoutSession(
        id: UUID(uuidString: "99999999-1000-0000-0000-000000000001")!,
        userId: ProgramSamples.userId,
        programDayId: ProgramSamples.upperDayId,
        startedAt: ProgramSamples.createdAt,
        endedAt: nil,
        notes: nil,
        createdAt: ProgramSamples.createdAt
    )
    var createdSessions: [(programDayId: UUID, startedAt: Date)] = []
    var uploadedSets: [WorkoutSet] = []
    var deletedSetIds: [UUID] = []
    var completedSessions: [(sessionId: UUID, endedAt: Date)] = []
    var nextUploadError: AppError?
    var completeSessionError: AppError?

    func createSession(programDayId: UUID, startedAt: Date) async throws -> WorkoutSession {
        createdSessions.append((programDayId, startedAt))
        session.programDayId = programDayId
        session.startedAt = startedAt
        return session
    }

    func uploadSet(_ set: WorkoutSet) async throws -> WorkoutSet {
        if let nextUploadError {
            self.nextUploadError = nil
            uploadedSets.append(set)
            throw nextUploadError
        }
        uploadedSets.append(set)
        return set
    }

    func updateSet(_ set: WorkoutSet) async throws -> WorkoutSet {
        set
    }

    func deleteSet(id: UUID) async throws {
        deletedSetIds.append(id)
    }

    func completeSession(_ sessionId: UUID, endedAt: Date) async throws {
        if let completeSessionError {
            throw completeSessionError
        }
        completedSessions.append((sessionId, endedAt))
    }

    func fetchHistory(limit: Int) async throws -> [WorkoutSession] {
        [session]
    }
}

@MainActor
private final class FakeWorkoutProgramRepository: ProgramRepositoryProviding {
    var day = ProgramSamples.days[0]
    var programExercises = [ProgramSamples.benchProgramExercise]

    func fetchAll() async throws -> [Program] { ProgramSamples.programs }
    func fetchFull(id: UUID) async throws -> Program { ProgramSamples.program }
    func fetchDay(id: UUID) async throws -> ProgramDay { day }
    func fetchProgramExercises(dayId: UUID) async throws -> [ProgramExercise] { programExercises }
    func fetchActive() async throws -> Program? { ProgramSamples.program }
    func createProgram(name: String, description: String?) async throws -> Program { ProgramSamples.program }
    func updateProgramMetadata(id: UUID, name: String, description: String?) async throws -> Program { ProgramSamples.program }
    func delete(id: UUID) async throws {}
    func setActive(programId: UUID) async throws {}
    func createDay(programId: UUID, name: String, order: Int) async throws -> ProgramDay { day }
    func updateDay(id: UUID, name: String, order: Int) async throws -> ProgramDay { day }
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
    ) async throws -> ProgramExercise {
        ProgramSamples.benchProgramExercise
    }
    func updateProgramExercise(_ programExercise: ProgramExercise) async throws -> ProgramExercise { programExercise }
    func deleteProgramExercise(id: UUID) async throws {}
    func reorderProgramExercises(_ exercises: [ProgramExercise]) async throws {}
}

@MainActor
private final class FakeWorkoutExerciseRepository: ExerciseRepositoryProviding {
    func fetchAll() async throws -> [Exercise] {
        ProgramSamples.exercises
    }
}

@MainActor
private final class FakeBackupRepository: ActiveSessionBackupRepositoryProviding {
    var loadResult: Result<ActiveSessionSnapshot?, AppError> = .success(nil)
    var savedSnapshots: [ActiveSessionSnapshot] = []
    var clearCount = 0

    func loadBackup() -> Result<ActiveSessionSnapshot?, AppError> {
        loadResult
    }

    func saveBackup(_ snapshot: ActiveSessionSnapshot) -> Result<Void, AppError> {
        savedSnapshots.append(snapshot)
        return .success(())
    }

    func clearBackup() {
        clearCount += 1
    }
}
