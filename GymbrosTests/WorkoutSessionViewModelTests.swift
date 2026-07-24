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
        // start() no longer inserts remotely — session is built locally only
        #expect(workoutRepository.insertedSessions.isEmpty)
        #expect(data.session.programDayId == ProgramSamples.upperDayId)
        #expect(data.session.endedAt == nil)
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
            sessionId: UUID(),
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
        #expect(liveActivity.updates.last?.phase == .resting)
        #expect(liveActivity.updates.last?.restEndsAt != nil)
        #expect(liveActivity.updates.last?.nextWork?.programExerciseId == ProgramSamples.benchProgramExerciseId)
    }

    @Test func workoutStartStartsLiveActivityWithActiveCurrentSet() async throws {
        let liveActivity = FakeRestTimerLiveActivityController()
        let viewModel = makeViewModel(liveActivityController: liveActivity)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)

        let data = try successValue(viewModel.state)
        let started = try #require(liveActivity.starts.first)
        // Session id is a client-generated UUID from the ViewModel, not a preset fake id
        #expect(started.sessionId == data.session.id)
        #expect(started.programDayId == ProgramSamples.upperDayId)
        #expect(started.state.phase == .active)
        #expect(started.state.workoutName == "Upper A")
        #expect(started.state.workoutStartedAt == ProgramSamples.createdAt)
        #expect(started.state.currentWork?.programExerciseId == ProgramSamples.benchProgramExerciseId)
        #expect(started.state.currentWork?.setNumber == 1)
    }

    @Test func draftRepsUpdateRefreshesLiveActivity() async throws {
        let liveActivity = FakeRestTimerLiveActivityController()
        let viewModel = makeViewModel(liveActivityController: liveActivity)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "80", repsText: "9", rpe: nil)

        #expect(liveActivity.updates.last?.phase == .active)
        #expect(liveActivity.updates.last?.currentWork?.repsText == "9 reps")
        #expect(liveActivity.updates.last?.currentWork?.weightText == "80 kg")
    }

    @Test func prepareForScreenExitKeepsExternalSurfacesRunningAndSavesBackup() async throws {
        let scheduler = FakeRestTimerScheduler()
        let liveActivity = FakeRestTimerLiveActivityController()
        let backupRepository = FakeBackupRepository()
        let viewModel = makeViewModel(
            backupRepository: backupRepository,
            restTimerScheduler: scheduler,
            liveActivityController: liveActivity
        )

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let savedCountAfterStart = backupRepository.savedSnapshots.count
        viewModel.prepareForScreenExit()

        #expect(backupRepository.savedSnapshots.count == savedCountAfterStart + 1)
        #expect(scheduler.cancelAllCount == 0)
        #expect(liveActivity.endCount == 0)
        #expect(backupRepository.clearCount == 0)
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

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        await viewModel.markRestTimerComplete()

        #expect(liveActivity.updates.last?.phase == .ready)
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
        #expect(workoutRepository.insertedSessions.count == 1)
        #expect(workoutRepository.insertedSessions.first?.endedAt != nil)
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
        workoutRepository.insertSessionError = .network(.offline)
        await viewModel.finishSession()

        #expect(backupRepository.clearCount == 0)
        #expect(backupRepository.savedSnapshots.isEmpty == false)
        #expect(viewModel.transientError == .network(.offline))
    }

    @Test func finishSetUploadFailureRollsBackSessionAndKeepsBackup() async throws {
        // After insertSession succeeds, a set-upload error must trigger deleteSession
        // (rollback) and retain the local backup so the user can retry.
        let workoutRepository = FakeWorkoutRepository()
        let backupRepository = FakeBackupRepository()
        let viewModel = makeViewModel(workoutRepository: workoutRepository, backupRepository: backupRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "80", repsText: "8", rpe: nil)
        await viewModel.completeSet(setId: row.id)
        await viewModel.finishExercise(programExerciseId: ProgramSamples.benchProgramExerciseId)

        // Session inserts OK but the set upload fails
        workoutRepository.nextUploadError = .network(.offline)
        await viewModel.finishSession()

        // Session was inserted then rolled back
        #expect(workoutRepository.insertedSessions.count == 1)
        let data = try successValue(viewModel.state)
        #expect(workoutRepository.deletedSessionIds == [data.session.id])
        // Backup kept and error surfaced
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
        #expect(workoutRepository.insertedSessions.count == 1)
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
        #expect(workoutRepository.insertedSessions.count == 1)
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
        #expect(workoutRepository.insertedSessions.count == 1)
        #expect(workoutRepository.insertedSessions.first?.endedAt != nil)
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
        exerciseRepository: FakeWorkoutExerciseRepository? = nil,
        backupRepository: FakeBackupRepository? = nil,
        restTimerScheduler: FakeRestTimerScheduler? = nil,
        liveActivityController: FakeRestTimerLiveActivityController? = nil,
        analytics: AnalyticsTracking? = nil,
        overloadSuggestionTracker: FakeOverloadSuggestionTracker? = nil,
        baselineRegainedHaptic: (() -> Void)? = nil,
        weightUnit: WeightUnit = .kg
    ) -> WorkoutSessionViewModel {
        WorkoutSessionViewModel(
            workoutRepository: workoutRepository ?? FakeWorkoutRepository(),
            programRepository: programRepository ?? FakeWorkoutProgramRepository(),
            exerciseRepository: exerciseRepository ?? FakeWorkoutExerciseRepository(),
            backupRepository: backupRepository ?? FakeBackupRepository(),
            restTimerScheduler: restTimerScheduler ?? FakeRestTimerScheduler(),
            liveActivityController: liveActivityController ?? FakeRestTimerLiveActivityController(),
            analytics: analytics ?? NoopAnalytics(),
            overloadSuggestionTracker: overloadSuggestionTracker ?? FakeOverloadSuggestionTracker(),
            baselineRegainedHaptic: baselineRegainedHaptic ?? {},
            weightUnit: weightUnit,
            now: { ProgramSamples.createdAt },
            currentUserId: { ProgramSamples.userId }
        )
    }

    private func comebackRecommendation(
        baselineWeight: Double = 60,
        baselineReps: [Int] = [8, 8, 8]
    ) -> TodayRecommendation {
        let stage = SmartSessionAdvisor().stage(forDaysSinceLast: 15)
        let adjustment = ExerciseAdjustment(
            originalTargetWeight: baselineWeight,
            adjustedTargetWeight: baselineWeight * stage.weightMultiplier,
            originalSets: 3,
            adjustedSets: 2,
            baselineWeight: baselineWeight,
            baselineReps: baselineReps
        )
        return TodayRecommendation(
            mode: .comeback(stage: stage, adjustments: [ProgramSamples.benchProgramExerciseId: adjustment]),
            programDay: nil,
            reasonKey: stage.reasonKey,
            gapDays: 15
        )
    }

    // MARK: - Comeback mode

    @Test func comebackRecommendationAppliesAdjustedDefaults() async throws {
        let viewModel = makeViewModel()
        viewModel.recommendation = comebackRecommendation()

        await viewModel.start(programDayId: ProgramSamples.upperDayId)

        let section = try #require(successValue(viewModel.state).exerciseSections.first)
        #expect(viewModel.isComebackMode)
        #expect(section.sets.count == 2)
        #expect(section.sets.map(\.weightText) == ["54", ""])
    }

    @Test func comebackStartTracksEventAndBuildsBaselineReference() async throws {
        let spy = SpyWorkoutAnalytics()
        let viewModel = makeViewModel(analytics: spy)
        viewModel.recommendation = comebackRecommendation()

        await viewModel.start(programDayId: ProgramSamples.upperDayId)

        #expect(spy.events == [.comebackSessionStarted])
        let reference = try #require(viewModel.lastSessionReferences[ProgramSamples.benchProgramExerciseId])
        #expect(reference.label == .baseline)
        #expect(reference.sets.map(\.reps) == [8, 8, 8])
        #expect(reference.sets.first?.weight == 60)
    }

    @Test func baselineRegainedFiresOncePerSession() async throws {
        let spy = SpyWorkoutAnalytics()
        let haptics = HapticCounter()
        let viewModel = makeViewModel(analytics: spy, baselineRegainedHaptic: { haptics.count += 1 })
        viewModel.recommendation = comebackRecommendation()

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let rows = try successValue(viewModel.state).exerciseSections[0].sets

        // Reduced default (54 kg) stays below the 60 kg baseline.
        await viewModel.completeSet(setId: rows[0].id)
        #expect(haptics.count == 0)
        #expect(viewModel.baselineRegainedThisSession == false)

        await viewModel.updateDraft(setId: rows[1].id, weightText: "60", repsText: "8", rpe: nil)
        await viewModel.completeSet(setId: rows[1].id)
        #expect(haptics.count == 1)
        #expect(viewModel.baselineRegainedThisSession)
        #expect(spy.events.contains(.comebackExitBaselineReached))

        await viewModel.addSet(after: rows[1].id)
        let added = try #require(successValue(viewModel.state).exerciseSections[0].sets.last)
        await viewModel.updateDraft(setId: added.id, weightText: "62.5", repsText: "8", rpe: nil)
        await viewModel.completeSet(setId: added.id)
        #expect(haptics.count == 1)
    }

    @Test func finishSessionEmitsComebackFinishedEvent() async throws {
        let spy = SpyWorkoutAnalytics()
        let viewModel = makeViewModel(analytics: spy)
        viewModel.recommendation = comebackRecommendation()

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.completeSet(setId: row.id)
        await viewModel.finishExercise(programExerciseId: ProgramSamples.benchProgramExerciseId)
        await viewModel.finishSession()

        #expect(spy.events.contains(.comebackSessionFinished))
    }

    // MARK: - Overload suggestion outcome

    @Test func overloadSuggestionBadgePopulatesFromTrackerAtSessionStart() async throws {
        let tracker = FakeOverloadSuggestionTracker()
        tracker.recordSuggestion(programExerciseId: ProgramSamples.benchProgramExerciseId, previousWeight: 57.5)
        let viewModel = makeViewModel(overloadSuggestionTracker: tracker)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)

        let section = try #require(successValue(viewModel.state).exerciseSections.first)
        #expect(section.pendingOverloadPreviousWeight == 57.5)
    }

    @Test func completingSetBelowRpeNineQuietlyClearsSuggestionWithoutPrompting() async throws {
        let tracker = FakeOverloadSuggestionTracker()
        tracker.recordSuggestion(programExerciseId: ProgramSamples.benchProgramExerciseId, previousWeight: 57.5)
        let programRepository = FakeWorkoutProgramRepository()
        let viewModel = makeViewModel(programRepository: programRepository, overloadSuggestionTracker: tracker)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "60", repsText: "8", rpe: 7)
        await viewModel.completeSet(setId: row.id)

        #expect(viewModel.overloadOutcomePrompt == nil)
        #expect(tracker.clearedProgramExerciseIds == [ProgramSamples.benchProgramExerciseId])
        #expect(programRepository.updatedProgramExercises.isEmpty)
    }

    @Test func completingSetAtRpeNineOrAboveShowsKeepOrRevertPrompt() async throws {
        let tracker = FakeOverloadSuggestionTracker()
        tracker.recordSuggestion(programExerciseId: ProgramSamples.benchProgramExerciseId, previousWeight: 57.5)
        let viewModel = makeViewModel(overloadSuggestionTracker: tracker)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "60", repsText: "8", rpe: 9)
        await viewModel.completeSet(setId: row.id)

        let prompt = try #require(viewModel.overloadOutcomePrompt)
        #expect(prompt.programExercise.id == ProgramSamples.benchProgramExerciseId)
        #expect(prompt.exerciseName == "Bench Press")
        #expect(prompt.previousWeight == 57.5)
        #expect(prompt.newWeight == 60)
        // Not resolved yet -- the suggestion stays pending until the user answers the prompt.
        #expect(tracker.recordedPreviousWeights[ProgramSamples.benchProgramExerciseId] == 57.5)
    }

    @Test func keepingNewOverloadWeightClearsPromptWithoutChangingProgramExercise() async throws {
        let tracker = FakeOverloadSuggestionTracker()
        tracker.recordSuggestion(programExerciseId: ProgramSamples.benchProgramExerciseId, previousWeight: 57.5)
        let programRepository = FakeWorkoutProgramRepository()
        let viewModel = makeViewModel(programRepository: programRepository, overloadSuggestionTracker: tracker)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "60", repsText: "8", rpe: 9)
        await viewModel.completeSet(setId: row.id)
        _ = try #require(viewModel.overloadOutcomePrompt)

        viewModel.keepNewOverloadWeight()

        #expect(viewModel.overloadOutcomePrompt == nil)
        #expect(tracker.recordedPreviousWeights[ProgramSamples.benchProgramExerciseId] == nil)
        #expect(programRepository.updatedProgramExercises.isEmpty)
    }

    @Test func revertingOverloadWeightUpdatesProgramExerciseTargetWeight() async throws {
        let tracker = FakeOverloadSuggestionTracker()
        tracker.recordSuggestion(programExerciseId: ProgramSamples.benchProgramExerciseId, previousWeight: 57.5)
        let programRepository = FakeWorkoutProgramRepository()
        let viewModel = makeViewModel(programRepository: programRepository, overloadSuggestionTracker: tracker)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.updateDraft(setId: row.id, weightText: "60", repsText: "8", rpe: 10)
        await viewModel.completeSet(setId: row.id)
        _ = try #require(viewModel.overloadOutcomePrompt)

        await viewModel.revertOverloadWeight()

        #expect(viewModel.overloadOutcomePrompt == nil)
        #expect(tracker.recordedPreviousWeights[ProgramSamples.benchProgramExerciseId] == nil)
        #expect(programRepository.updatedProgramExercises.last?.id == ProgramSamples.benchProgramExerciseId)
        #expect(programRepository.updatedProgramExercises.last?.targetWeight == 57.5)
    }

    @Test func overloadOutcomeIsOnlyResolvedOnceInASession() async throws {
        let tracker = FakeOverloadSuggestionTracker()
        tracker.recordSuggestion(programExerciseId: ProgramSamples.benchProgramExerciseId, previousWeight: 57.5)
        let viewModel = makeViewModel(overloadSuggestionTracker: tracker)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let rows = try successValue(viewModel.state).exerciseSections[0].sets
        await viewModel.updateDraft(setId: rows[0].id, weightText: "60", repsText: "8", rpe: 9)
        await viewModel.completeSet(setId: rows[0].id)
        _ = try #require(viewModel.overloadOutcomePrompt)
        viewModel.keepNewOverloadWeight()

        await viewModel.updateDraft(setId: rows[1].id, weightText: "60", repsText: "8", rpe: 9)
        await viewModel.completeSet(setId: rows[1].id)

        #expect(viewModel.overloadOutcomePrompt == nil)
    }

    // MARK: - Substitute

    @Test func presentSubstituteOptionsBuildsRankedCandidatesExcludingCurrentExercise() async throws {
        let workoutRepository = FakeWorkoutRepository()
        let viewModel = makeViewModel(workoutRepository: workoutRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        await viewModel.presentSubstituteOptions(programExerciseId: ProgramSamples.benchProgramExerciseId)

        let prompt = try #require(viewModel.substitutePrompt)
        #expect(prompt.programExerciseId == ProgramSamples.benchProgramExerciseId)
        #expect(prompt.originalExercise.id == ProgramSamples.benchExerciseId)
        #expect(prompt.candidates.map(\.exercise.id) == [ProgramSamples.machineChestPressExerciseId])
        // Only one matching candidate exists in the fixture library -- below the
        // 3-result threshold, so the browse-all fallback should be offered.
        #expect(prompt.showsBrowseAllFallback)
    }

    @Test func presentSubstituteOptionsHidesBrowseAllFallbackAtThreeOrMoreCandidates() async throws {
        let exerciseRepository = FakeWorkoutExerciseRepository()
        exerciseRepository.exercises = ProgramSamples.exercises + [
            makeChestExercise(name: "Cable Chest Fly", equipment: .cable),
            makeChestExercise(name: "Dumbbell Bench Press", equipment: .dumbbell)
        ]
        let viewModel = makeViewModel(exerciseRepository: exerciseRepository)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        await viewModel.presentSubstituteOptions(programExerciseId: ProgramSamples.benchProgramExerciseId)

        let prompt = try #require(viewModel.substitutePrompt)
        #expect(prompt.candidates.count == 3)
        #expect(prompt.showsBrowseAllFallback == false)
    }

    @Test func selectSubstituteReassignsNotYetCompletedRowsAndPreservesCompletedRows() async throws {
        let workoutRepository = FakeWorkoutRepository()
        workoutRepository.lastLoggedSets[ProgramSamples.machineChestPressExerciseId] = WorkoutSet(
            id: UUID(),
            sessionId: UUID(),
            exerciseId: ProgramSamples.machineChestPressExerciseId,
            programExerciseId: nil,
            setNumber: 1,
            weight: 40,
            reps: 10,
            rpe: nil,
            targetRestSeconds: nil,
            actualRestSeconds: nil,
            restStartedAt: nil,
            restEndedAt: nil,
            completedAt: ProgramSamples.createdAt.addingTimeInterval(-86_400),
            notes: nil
        )
        let spy = SpyWorkoutAnalytics()
        let viewModel = makeViewModel(workoutRepository: workoutRepository, analytics: spy)

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let firstSetId = try firstRow(viewModel).id
        await viewModel.updateDraft(setId: firstSetId, weightText: "62.5", repsText: "8", rpe: nil)
        await viewModel.completeSet(setId: firstSetId)

        await viewModel.presentSubstituteOptions(programExerciseId: ProgramSamples.benchProgramExerciseId)
        await viewModel.selectSubstitute(ProgramSamples.machineChestPress)

        #expect(viewModel.substitutePrompt == nil)
        #expect(spy.events == [.exerciseSubstituted, .substituteRankSelected])

        let section = try #require(successValue(viewModel.state).exerciseSections.first)
        #expect(section.exercise?.id == ProgramSamples.machineChestPressExerciseId)
        #expect(section.defaultWeight == 40)

        let completedRow = try #require(section.sets.first)
        #expect(completedRow.isCompleted)
        #expect(completedRow.exerciseId == ProgramSamples.benchExerciseId)
        #expect(completedRow.weightText == "62.5")

        let remainingRows = section.sets.dropFirst()
        #expect(remainingRows.allSatisfy { $0.exerciseId == ProgramSamples.machineChestPressExerciseId })
        #expect(remainingRows.allSatisfy { $0.weightText == "40" })
    }

    @Test func addSetAfterSwapUsesTheSubstituteExerciseId() async throws {
        let viewModel = makeViewModel()

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        await viewModel.presentSubstituteOptions(programExerciseId: ProgramSamples.benchProgramExerciseId)
        await viewModel.selectSubstitute(ProgramSamples.machineChestPress)

        let lastRow = try #require(successValue(viewModel.state).exerciseSections.first?.sets.last)
        await viewModel.addSet(after: lastRow.id)

        let added = try #require(successValue(viewModel.state).exerciseSections.first?.sets.last)
        #expect(added.exerciseId == ProgramSamples.machineChestPressExerciseId)
    }

    private func makeChestExercise(name: String, equipment: Equipment) -> Exercise {
        Exercise(
            id: UUID(),
            ownerUserId: nil,
            slug: name.lowercased().replacingOccurrences(of: " ", with: "_"),
            name: name,
            movementPattern: .push,
            primaryMuscle: .chest,
            secondaryMuscles: [],
            equipment: equipment,
            isCompound: true,
            createdAt: ProgramSamples.createdAt
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

private final class SpyWorkoutAnalytics: AnalyticsTracking {
    var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
}

private final class HapticCounter {
    var count = 0
}

@MainActor
private final class FakeWorkoutRepository: WorkoutRepositoryProviding {
    var insertedSessions: [WorkoutSession] = []
    var uploadedSets: [WorkoutSet] = []
    var updatedSets: [WorkoutSet] = []
    var deletedSetIds: [UUID] = []
    var deletedSessionIds: [UUID] = []
    var lastLoggedSets: [UUID: WorkoutSet] = [:]
    var history: [WorkoutSession] = []
    var setsBySessionId: [UUID: [WorkoutSet]] = [:]
    var rpeUpdates: [(ids: [UUID], rpe: Double)] = []
    var updateSetsError: AppError?
    var nextUploadError: AppError?
    var insertSessionError: AppError?
    var lastLoggedSetError: AppError?
    var fetchSetsError: AppError?
    var sets: [WorkoutSet] = []

    func insertSession(_ session: WorkoutSession) async throws {
        if let insertSessionError {
            throw insertSessionError
        }
        insertedSessions.append(session)
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

    func updateSets(ids: [UUID], rpe: Double) async throws {
        if let updateSetsError {
            throw updateSetsError
        }
        rpeUpdates.append((ids, rpe))
    }

    func deleteSet(id: UUID) async throws {
        deletedSetIds.append(id)
    }

    func deleteSession(id: UUID) async throws {
        deletedSessionIds.append(id)
    }

    func completeSession(_ sessionId: UUID, endedAt: Date) async throws {}

    func updateSessionEndedAt(sessionId: UUID, endedAt: Date) async throws -> WorkoutSession {
        WorkoutSession(
            id: sessionId,
            userId: ProgramSamples.userId,
            programDayId: ProgramSamples.upperDayId,
            startedAt: endedAt.addingTimeInterval(-3600),
            endedAt: endedAt,
            notes: nil,
            createdAt: endedAt.addingTimeInterval(-3600)
        )
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
    var starts: [(sessionId: UUID, programDayId: UUID?, state: RestTimerActivityAttributes.ContentState)] = []
    var updates: [RestTimerActivityAttributes.ContentState] = []
    var endCount = 0

    func start(
        sessionId: UUID,
        programDayId: UUID?,
        state: RestTimerActivityAttributes.ContentState
    ) async {
        starts.append((sessionId, programDayId, state))
    }

    func update(_ state: RestTimerActivityAttributes.ContentState) async {
        updates.append(state)
    }

    func end() async {
        endCount += 1
    }
}

@MainActor
private final class FakeWorkoutProgramRepository: ProgramRepositoryProviding {
    var day = ProgramSamples.days[0]
    var programExercises = [ProgramSamples.benchProgramExercise]
    var updatedProgramExercises: [ProgramExercise] = []

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
    func updateProgramExercise(_ programExercise: ProgramExercise) async throws -> ProgramExercise {
        updatedProgramExercises.append(programExercise)
        return programExercise
    }
    func deleteProgramExercise(id: UUID) async throws {}
    func reorderProgramExercises(_ exercises: [ProgramExercise]) async throws {}
}

@MainActor
private final class FakeOverloadSuggestionTracker: OverloadSuggestionTracking {
    var recordedPreviousWeights: [UUID: Double] = [:]
    var clearedProgramExerciseIds: [UUID] = []

    func pendingPreviousWeight(programExerciseId: UUID) -> Double? { recordedPreviousWeights[programExerciseId] }
    func recordSuggestion(programExerciseId: UUID, previousWeight: Double) {
        recordedPreviousWeights[programExerciseId] = previousWeight
    }
    func clearSuggestion(programExerciseId: UUID) {
        recordedPreviousWeights.removeValue(forKey: programExerciseId)
        clearedProgramExerciseIds.append(programExerciseId)
    }
}

@MainActor
private final class FakeWorkoutExerciseRepository: ExerciseRepositoryProviding {
    var exercises: [Exercise] = ProgramSamples.exercises

    func fetchAll() async throws -> [Exercise] {
        exercises
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
