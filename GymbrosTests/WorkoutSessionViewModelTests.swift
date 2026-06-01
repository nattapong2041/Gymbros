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
        #expect(data.currentExerciseIndex == 0)
        #expect(data.exerciseSections[0].defaultWeight == 60)
        #expect(data.exerciseSections[0].sets.count == ProgramSamples.benchProgramExercise.targetSets)
        #expect(data.exerciseSections[0].sets.map(\.weightText) == ["60", "", ""])
        #expect(data.exerciseSections[0].sets.map(\.repsText) == ["8", "", ""])
    }

    @Test func poundWeightUnitDisplaysDefaultsInPoundsAndUploadsKilograms() async throws {
        let workoutRepository = FakeWorkoutRepository()
        let viewModel = makeViewModel(workoutRepository: workoutRepository, weightUnit: .lb)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        var row = try firstRow(viewModel)

        #expect(row.weightText == "132.28")

        await viewModel.updateDraft(setId: row.id, weightText: "135", repsText: "8", rpe: nil)
        row = try firstRow(viewModel)
        await viewModel.completeSet(setId: row.id)
        await viewModel.finishExercise(programExerciseId: ProgramSamples.benchProgramExerciseId)
        await viewModel.finishSession()

        let uploaded = try #require(workoutRepository.uploadedSets.first)
        #expect(uploaded.weight > 61.2)
        #expect(uploaded.weight < 61.3)
    }

    @Test func changingWeightUnitConvertsExistingDraftText() async throws {
        let viewModel = makeViewModel()

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "60", repsText: "8", rpe: nil)
        viewModel.updateWeightUnit(.lb)

        #expect(try rowState(viewModel, id: row.id).weightText == "132.28")
    }

    @Test func startFallsBackToLastLoggedWeightWhenTargetWeightIsNil() async throws {
        let workoutRepository = FakeWorkoutRepository()
        workoutRepository.lastLoggedSets[ProgramSamples.squatExerciseId] = WorkoutSet(
            id: UUID(),
            sessionId: workoutRepository.session.id,
            exerciseId: ProgramSamples.squatExerciseId,
            programExerciseId: ProgramSamples.squatProgramExerciseId,
            setNumber: 1,
            weight: 102.5,
            reps: 5,
            rpe: nil,
            targetRestSeconds: nil,
            actualRestSeconds: nil,
            restStartedAt: nil,
            restEndedAt: nil,
            completedAt: ProgramSamples.createdAt.addingTimeInterval(-86_400),
            notes: nil
        )
        let programRepository = FakeWorkoutProgramRepository()
        programRepository.programExercises = [ProgramSamples.squatProgramExercise]
        let viewModel = makeViewModel(workoutRepository: workoutRepository, programRepository: programRepository)

        await viewModel.start(programDayId: ProgramSamples.lowerDayId)

        let section = try #require(successValue(viewModel.state).exerciseSections.first)
        #expect(section.defaultWeight == 102.5)
        #expect(section.sets.map(\.weightText) == ["102.5", "", ""])
    }

    @Test func startContinuesWithBlankDefaultWhenLastLoggedLookupFails() async throws {
        let workoutRepository = FakeWorkoutRepository()
        workoutRepository.lastLoggedSetError = .network(.offline)
        let programRepository = FakeWorkoutProgramRepository()
        programRepository.programExercises = [ProgramSamples.squatProgramExercise]
        let viewModel = makeViewModel(workoutRepository: workoutRepository, programRepository: programRepository)

        await viewModel.start(programDayId: ProgramSamples.lowerDayId)

        let section = try #require(successValue(viewModel.state).exerciseSections.first)
        #expect(section.defaultWeight == nil)
        #expect(section.sets.map(\.weightText) == ["", "", ""])
        #expect(viewModel.transientError == nil)
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

    @Test func completeSetDoesNotUpload() async throws {
        let workoutRepository = FakeWorkoutRepository()
        let viewModel = makeViewModel(workoutRepository: workoutRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "80", repsText: "8", rpe: 7.5)
        await viewModel.completeSet(setId: row.id)

        #expect(workoutRepository.uploadedSets.isEmpty)
        #expect(try rowState(viewModel, id: row.id).isCompleted)
    }

    @Test func completeSetSchedulesRestTimerSurfaces() async throws {
        let scheduler = FakeRestTimerScheduler()
        let liveActivity = FakeRestTimerLiveActivityController()
        let viewModel = makeViewModel(
            restTimerScheduler: scheduler,
            liveActivityController: liveActivity
        )

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "80", repsText: "8", rpe: nil)
        await viewModel.completeSet(setId: row.id)

        #expect(scheduler.scheduled.count == 1)
        #expect(scheduler.scheduled[0].programDayId == ProgramSamples.upperDayId)
        #expect(scheduler.scheduled[0].programExerciseId == ProgramSamples.benchProgramExerciseId)
        #expect(liveActivity.starts.count == 1)
    }

    @Test func restTimerRequestsNotificationAuthorization() async throws {
        let scheduler = FakeRestTimerScheduler()
        let viewModel = makeViewModel(restTimerScheduler: scheduler)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "80", repsText: "8", rpe: nil)
        await viewModel.completeSet(setId: row.id)

        #expect(scheduler.requestAuthorizationCount == 1)
    }

    @Test func markRestTimerCompleteUpdatesLiveActivity() async {
        let liveActivity = FakeRestTimerLiveActivityController()
        let viewModel = makeViewModel(liveActivityController: liveActivity)

        await viewModel.markRestTimerComplete()

        #expect(liveActivity.markCompleteCount == 1)
    }

    @Test func lastSessionReferencesPopulateAfterStart() async throws {
        let workoutRepository = FakeWorkoutRepository()
        let historySession = WorkoutSession(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            userId: ProgramSamples.userId,
            programDayId: ProgramSamples.upperDayId,
            startedAt: ProgramSamples.createdAt.addingTimeInterval(-86_400),
            endedAt: ProgramSamples.createdAt.addingTimeInterval(-82_800),
            notes: nil,
            createdAt: ProgramSamples.createdAt.addingTimeInterval(-86_400)
        )
        workoutRepository.history = [historySession]
        workoutRepository.setsBySessionId[historySession.id] = [
            WorkoutSet(id: UUID(), sessionId: historySession.id, exerciseId: ProgramSamples.benchExerciseId, programExerciseId: ProgramSamples.benchProgramExerciseId, setNumber: 1, weight: 60, reps: 8, rpe: nil, targetRestSeconds: nil, actualRestSeconds: nil, restStartedAt: nil, restEndedAt: nil, completedAt: ProgramSamples.createdAt.addingTimeInterval(-85_000), notes: nil),
            WorkoutSet(id: UUID(), sessionId: historySession.id, exerciseId: ProgramSamples.benchExerciseId, programExerciseId: ProgramSamples.benchProgramExerciseId, setNumber: 2, weight: 60, reps: 7, rpe: nil, targetRestSeconds: nil, actualRestSeconds: nil, restStartedAt: nil, restEndedAt: nil, completedAt: ProgramSamples.createdAt.addingTimeInterval(-84_000), notes: nil)
        ]
        let viewModel = makeViewModel(workoutRepository: workoutRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)

        let reference = try #require(viewModel.lastSessionReferences[ProgramSamples.benchProgramExerciseId])
        #expect(reference.weight == 60)
        #expect(reference.reps == [8, 7])
        #expect(reference.sets == [
            .init(weight: 60, reps: 8),
            .init(weight: 60, reps: 7)
        ])
        #expect(reference.isFallback == false)
    }

    @Test func completeSetCopiesActualWeightAndRepsToNextUnmodifiedRowWithoutRPE() async throws {
        let viewModel = makeViewModel()

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "82.5", repsText: "9", rpe: 8.5)
        await viewModel.completeSet(setId: row.id)

        let sets = try successValue(viewModel.state).exerciseSections[0].sets
        #expect(sets[1].weightText == "82.5")
        #expect(sets[1].repsText == "9")
        #expect(sets[1].rpe == nil)
    }

    @Test func completeSetDoesNotChangeCurrentExerciseIndex() async throws {
        let programRepository = FakeWorkoutProgramRepository()
        programRepository.programExercises = [ProgramSamples.benchProgramExercise, ProgramSamples.squatProgramExercise]
        let viewModel = makeViewModel(programRepository: programRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        viewModel.goToExercise(index: 1)
        let row = try successValue(viewModel.state).exerciseSections[1].sets[0]
        await viewModel.updateDraft(setId: row.id, weightText: "100", repsText: "5", rpe: nil)
        await viewModel.completeSet(setId: row.id)

        #expect(try successValue(viewModel.state).currentExerciseIndex == 1)
    }

    @Test func finishExerciseMarksFinishedAndAdvancesToNextUnfinished() async throws {
        let programRepository = FakeWorkoutProgramRepository()
        programRepository.programExercises = [ProgramSamples.benchProgramExercise, ProgramSamples.squatProgramExercise]
        let viewModel = makeViewModel(programRepository: programRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try successValue(viewModel.state).exerciseSections[0].sets[0]
        await viewModel.updateDraft(setId: row.id, weightText: "80", repsText: "8", rpe: nil)
        await viewModel.completeSet(setId: row.id)
        await viewModel.finishExercise(programExerciseId: ProgramSamples.benchProgramExerciseId)

        let data = try successValue(viewModel.state)
        #expect(data.exerciseSections[0].isFinished)
        #expect(data.exerciseSections[0].finishedAt == ProgramSamples.createdAt)
        #expect(data.currentExerciseIndex == 1)
    }

    @Test func finishExerciseAllowsSkippingSectionWithoutUploadedSet() async throws {
        let viewModel = makeViewModel()

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        await viewModel.finishExercise(programExerciseId: ProgramSamples.benchProgramExerciseId)

        #expect(viewModel.transientError == nil)
        #expect(try successValue(viewModel.state).exerciseSections[0].isFinished)
    }

    @Test func uploadConflictUpdatesExistingSetAndAllowsFinish() async throws {
        let workoutRepository = FakeWorkoutRepository()
        workoutRepository.nextUploadError = .conflict
        let backupRepository = FakeBackupRepository()
        let viewModel = makeViewModel(workoutRepository: workoutRepository, backupRepository: backupRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "80", repsText: "8", rpe: nil)
        await viewModel.completeSet(setId: row.id)
        await viewModel.finishExercise(programExerciseId: ProgramSamples.benchProgramExerciseId)
        await viewModel.finishSession()

        #expect(workoutRepository.updatedSets.map(\.id) == [row.id])
        #expect(workoutRepository.completedSessions.map(\.sessionId) == [workoutRepository.session.id])
        #expect(backupRepository.clearCount == 1)
    }

    @Test func restoreMovesToFirstUnfinishedExercise() async throws {
        var snapshot = makeSnapshot()
        snapshot.programExercises = [ProgramSamples.benchProgramExercise, ProgramSamples.squatProgramExercise]
        snapshot.finishedExerciseIds = [ProgramSamples.benchProgramExerciseId]
        snapshot.currentExerciseIndex = 0
        snapshot.defaultWeights = [
            ProgramSamples.benchProgramExerciseId: 60,
            ProgramSamples.squatProgramExerciseId: 100
        ]
        let viewModel = makeViewModel()

        await viewModel.restore(snapshot)

        let data = try successValue(viewModel.state)
        #expect(data.exerciseSections[0].isFinished)
        #expect(data.exerciseSections[1].isFinished == false)
        #expect(data.exerciseSections[1].defaultWeight == 100)
        #expect(data.currentExerciseIndex == 1)
    }

    @Test func finishDoesNotClearBackupWhenCompletionFails() async throws {
        let workoutRepository = FakeWorkoutRepository()
        let backupRepository = FakeBackupRepository()
        let viewModel = makeViewModel(workoutRepository: workoutRepository, backupRepository: backupRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "80", repsText: "8", rpe: nil)
        await viewModel.completeSet(setId: row.id)
        await viewModel.finishExercise(programExerciseId: ProgramSamples.benchProgramExerciseId)
        workoutRepository.completeSessionError = .network(.offline)
        await viewModel.finishSession()

        #expect(backupRepository.clearCount == 0)
        #expect(backupRepository.savedSnapshots.isEmpty == false)
        #expect(viewModel.transientError == .network(.offline))
    }

    @Test func finishSessionSkipsInvalidSets() async throws {
        // A completed set whose text is later edited to an out-of-range value is
        // skipped during batch upload — the session still finishes successfully.
        let workoutRepository = FakeWorkoutRepository()
        let backupRepository = FakeBackupRepository()
        let viewModel = makeViewModel(workoutRepository: workoutRepository, backupRepository: backupRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)

        await viewModel.updateDraft(setId: row.id, weightText: "59", repsText: "8", rpe: nil)
        await viewModel.completeSet(setId: row.id)
        #expect(try rowState(viewModel, id: row.id).isCompleted)

        // Edit reps to out-of-range — set is marked completed but invalid text
        await viewModel.updateDraft(setId: row.id, weightText: "59", repsText: "110", rpe: nil)

        await viewModel.finishExercise(programExerciseId: ProgramSamples.benchProgramExerciseId)
        await viewModel.finishSession()

        #expect(viewModel.transientError == nil)
        #expect(workoutRepository.completedSessions.map(\.sessionId) == [workoutRepository.session.id])
    }

    @Test func finishSessionUploadsAllCompletedSets() async throws {
        let workoutRepository = FakeWorkoutRepository()
        let backupRepository = FakeBackupRepository()
        let programRepository = FakeWorkoutProgramRepository()
        programRepository.programExercises = [ProgramSamples.benchProgramExercise]
        let viewModel = makeViewModel(workoutRepository: workoutRepository, programRepository: programRepository, backupRepository: backupRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let sets = try successValue(viewModel.state).exerciseSections[0].sets
        for row in sets {
            await viewModel.updateDraft(setId: row.id, weightText: "80", repsText: "8", rpe: nil)
            await viewModel.completeSet(setId: row.id)
        }
        #expect(workoutRepository.uploadedSets.isEmpty)

        await viewModel.finishExercise(programExerciseId: ProgramSamples.benchProgramExerciseId)
        await viewModel.finishSession()

        #expect(workoutRepository.uploadedSets.count == sets.count)
        #expect(workoutRepository.completedSessions.count == 1)
        #expect(backupRepository.clearCount == 1)
    }

    @Test func finishClearsBackupWhenCompletionSucceeds() async throws {
        let workoutRepository = FakeWorkoutRepository()
        let backupRepository = FakeBackupRepository()
        let viewModel = makeViewModel(workoutRepository: workoutRepository, backupRepository: backupRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "80", repsText: "8", rpe: nil)
        await viewModel.completeSet(setId: row.id)
        await viewModel.finishExercise(programExerciseId: ProgramSamples.benchProgramExerciseId)
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
        programRepository: FakeWorkoutProgramRepository? = nil,
        backupRepository: FakeBackupRepository? = nil,
        restTimerScheduler: FakeRestTimerScheduler? = nil,
        liveActivityController: FakeRestTimerLiveActivityController? = nil,
        weightUnit: WeightUnit = .kg
    ) -> WorkoutSessionViewModel {
        WorkoutSessionViewModel(
            workoutRepository: workoutRepository ?? FakeWorkoutRepository(),
            programRepository: programRepository ?? FakeWorkoutProgramRepository(),
            exerciseRepository: FakeWorkoutExerciseRepository(),
            backupRepository: backupRepository ?? FakeBackupRepository(),
            restTimerScheduler: restTimerScheduler ?? FakeRestTimerScheduler(),
            liveActivityController: liveActivityController ?? FakeRestTimerLiveActivityController(),
            weightUnit: weightUnit,
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
    var updatedSets: [WorkoutSet] = []
    var deletedSetIds: [UUID] = []
    var completedSessions: [(sessionId: UUID, endedAt: Date)] = []
    var lastLoggedSets: [UUID: WorkoutSet] = [:]
    var history: [WorkoutSession] = []
    var setsBySessionId: [UUID: [WorkoutSet]] = [:]
    var nextUploadError: AppError?
    var completeSessionError: AppError?
    var lastLoggedSetError: AppError?
    var fetchSetsError: AppError?
    var sets: [WorkoutSet] = []

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
        updatedSets.append(set)
        return set
    }

    func deleteSet(id: UUID) async throws {
        deletedSetIds.append(id)
    }

    func deleteSession(id: UUID) async throws {}

    func completeSession(_ sessionId: UUID, endedAt: Date) async throws {
        if let completeSessionError {
            throw completeSessionError
        }
        completedSessions.append((sessionId, endedAt))
    }

    func updateSessionEndedAt(sessionId: UUID, endedAt: Date) async throws -> WorkoutSession {
        session.endedAt = endedAt
        return session
    }

    func fetchLastLoggedSet(exerciseId: UUID, before: Date) async throws -> WorkoutSet? {
        if let lastLoggedSetError {
            throw lastLoggedSetError
        }
        return lastLoggedSets[exerciseId]
    }

    func fetchHistory(limit: Int) async throws -> [WorkoutSession] {
        history
    }

    func fetchSets(sessionId: UUID) async throws -> [WorkoutSet] {
        if let fetchSetsError {
            throw fetchSetsError
        }
        return setsBySessionId[sessionId] ?? sets
    }
}

@MainActor
private final class FakeRestTimerScheduler: RestTimerScheduling {
    var requestAuthorizationCount = 0
    var scheduled: [(seconds: TimeInterval, sessionId: UUID, programDayId: UUID?, programExerciseId: UUID?)] = []
    var cancelledSessionIds: [UUID] = []
    var cancelAllCount = 0

    func requestAuthorizationIfNeeded() async {
        requestAuthorizationCount += 1
    }

    func schedule(
        after seconds: TimeInterval,
        sessionId: UUID,
        programDayId: UUID?,
        programExerciseId: UUID?
    ) async {
        scheduled.append((seconds, sessionId, programDayId, programExerciseId))
    }

    func cancel(sessionId: UUID) {
        cancelledSessionIds.append(sessionId)
    }

    func cancelAll() {
        cancelAllCount += 1
    }
}

@MainActor
private final class FakeRestTimerLiveActivityController: RestTimerLiveActivityControlling {
    var starts: [(state: RestTimerState, sessionId: UUID, programDayId: UUID?, programExerciseId: UUID?, exerciseName: String)] = []
    var endCount = 0
    var markCompleteCount = 0

    func start(
        state: RestTimerState,
        sessionId: UUID,
        programDayId: UUID?,
        programExerciseId: UUID?,
        exerciseName: String
    ) async {
        starts.append((state, sessionId, programDayId, programExerciseId, exerciseName))
    }

    func end() async {
        endCount += 1
    }

    func markComplete() async {
        markCompleteCount += 1
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
