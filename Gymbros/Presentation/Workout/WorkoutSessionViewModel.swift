import Foundation
import Observation
import OSLog
import UIKit

private let workoutLogger = Logger(subsystem: "com.nattapongsawa.gymbros", category: "WorkoutSessionViewModel")

struct OverloadOutcomePrompt: Identifiable {
    let id: UUID
    let programExercise: ProgramExercise
    let exerciseName: String
    let newWeight: Double
    let previousWeight: Double
}

@MainActor
@Observable
final class WorkoutSessionViewModel {
    var state: ViewState<WorkoutSessionData> = .idle
    var transientError: AppError?
    var activeTimer: RestTimerState?
    var isFinishing = false
    var pendingRestore: ActiveSessionSnapshot?
    var lastSessionReferences: [UUID: LastSessionReference] = [:]
    var recommendation: TodayRecommendation = .normalDefault
    var overloadOutcomePrompt: OverloadOutcomePrompt?
    private(set) var baselineRegainedThisSession = false
    private var overloadOutcomesHandled: Set<UUID> = []

    var isComebackMode: Bool { recommendation.mode.isComeback }

    private let workoutRepository: WorkoutRepositoryProviding
    private let programRepository: ProgramRepositoryProviding
    private let exerciseRepository: ExerciseRepositoryProviding
    private let backupRepository: ActiveSessionBackupRepositoryProviding
    private let restTimerScheduler: RestTimerScheduling
    private let liveActivityController: RestTimerLiveActivityControlling
    private let lastSessionLookupService: LastSessionLookupService
    private let analytics: AnalyticsTracking
    private let overloadSuggestionTracker: OverloadSuggestionTracking
    private let playBaselineRegainedHaptic: () -> Void
    private let now: () -> Date
    private let currentUserId: @MainActor () -> UUID?
    private var weightUnit: WeightUnit

    init(
        workoutRepository: WorkoutRepositoryProviding? = nil,
        programRepository: ProgramRepositoryProviding? = nil,
        exerciseRepository: ExerciseRepositoryProviding? = nil,
        backupRepository: ActiveSessionBackupRepositoryProviding? = nil,
        restTimerScheduler: RestTimerScheduling? = nil,
        liveActivityController: RestTimerLiveActivityControlling? = nil,
        lastSessionLookupService: LastSessionLookupService = LastSessionLookupService(),
        analytics: AnalyticsTracking? = nil,
        overloadSuggestionTracker: OverloadSuggestionTracking? = nil,
        baselineRegainedHaptic: (() -> Void)? = nil,
        weightUnit: WeightUnit = .kg,
        now: @escaping () -> Date = Date.init,
        currentUserId: @escaping @MainActor () -> UUID? = { AuthService.shared.currentUser?.id }
    ) {
        self.workoutRepository = workoutRepository ?? WorkoutRepository()
        self.programRepository = programRepository ?? ProgramRepository()
        self.exerciseRepository = exerciseRepository ?? ExerciseRepository()
        self.backupRepository = backupRepository ?? ActiveSessionBackupRepository()
        self.restTimerScheduler = restTimerScheduler ?? RestTimerNotificationScheduler()
        self.liveActivityController = liveActivityController ?? RestTimerLiveActivityController()
        self.lastSessionLookupService = lastSessionLookupService
        self.analytics = analytics ?? AnalyticsProvider.makeDefault()
        self.overloadSuggestionTracker = overloadSuggestionTracker ?? OverloadSuggestionTracker()
        self.playBaselineRegainedHaptic = baselineRegainedHaptic ?? Self.playDoubleImpactHaptic
        self.weightUnit = weightUnit
        self.now = now
        self.currentUserId = currentUserId
    }

    private static func playDoubleImpactHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            generator.impactOccurred()
        }
    }

    func checkForRestore() async {
        switch backupRepository.loadBackup() {
        case .success(let snapshot):
            pendingRestore = snapshot
        case .failure(let error):
            transientError = error.isVisibleToUser ? error : nil
            pendingRestore = nil
        }
    }

    func start(programDayId: UUID) async {
        transientError = nil
        pendingRestore = nil
        activeTimer = nil
        state = .loading

        do {
            async let dayTask = programRepository.fetchDay(id: programDayId)
            async let programExercisesTask = programRepository.fetchProgramExercises(dayId: programDayId)
            async let exercisesTask = exerciseRepository.fetchAll()

            let (day, programExercises, exercises) = try await (dayTask, programExercisesTask, exercisesTask)
            let orderedProgramExercises = ProgramOrderNormalizer.normalizeProgramExercises(programExercises)
            guard orderedProgramExercises.isEmpty == false else {
                state = .empty
                return
            }

            let startedAt = now()
            guard let userId = currentUserId() else {
                state = .error(.auth(.sessionMissing))
                return
            }
            let session = WorkoutSession(
                id: UUID(),
                userId: userId,
                programDayId: programDayId,
                startedAt: startedAt,
                endedAt: nil,
                notes: nil,
                createdAt: startedAt
            )
            let exerciseLookup = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
            let defaultWeights = await resolveDefaultWeights(for: orderedProgramExercises, before: startedAt)
            let rowStates = makeInitialRows(from: orderedProgramExercises, defaultWeights: defaultWeights)
            setSuccess(
                session: session,
                day: day,
                programExercises: orderedProgramExercises,
                exerciseLookup: exerciseLookup,
                rowStates: rowStates,
                startedAt: startedAt,
                currentExerciseIndex: 0,
                finishedExerciseIds: [],
                defaultWeights: defaultWeights
            )
            if isComebackMode {
                analytics.track(.comebackSessionStarted)
            }
            await startWorkoutLiveActivity()
            await buildLastSessionReferences()
            saveBackup()
        } catch {
            let appError = appError(error, operation: "startWorkoutSession")
            if appError == .cancelled {
                state = .idle
            } else {
                state = .error(appError)
            }
        }
    }

    func restore(_ snapshot: ActiveSessionSnapshot) async {
        guard snapshot.version == ActiveSessionSnapshot.currentVersion else {
            transientError = .decoding
            pendingRestore = snapshot
            return
        }

        pendingRestore = nil
        activeTimer = snapshot.activeTimer
        let finishedExerciseIds = Set(snapshot.finishedExerciseIds)
        let defaultWeights = snapshot.defaultWeights ?? [:]
        setSuccess(
            session: snapshot.session,
            day: snapshot.day,
            programExercises: snapshot.programExercises,
            exerciseLookup: snapshot.exerciseLookup,
            rowStates: snapshot.rowStates.map(WorkoutSetRowState.init(snapshot:)),
            startedAt: snapshot.session.startedAt,
            currentExerciseIndex: 0,
            finishedExerciseIds: finishedExerciseIds,
            defaultWeights: defaultWeights
        )
        await buildLastSessionReferences()
        moveToFirstUnfinishedExercise()
        await startWorkoutLiveActivity()
        saveBackup()
    }

    func discardRestore(_ snapshot: ActiveSessionSnapshot) async {
        if pendingRestore?.session.id == snapshot.session.id {
            pendingRestore = nil
        }
        backupRepository.clearBackup()
        await liveActivityController.end()
    }

    func updateDraft(setId: UUID, weightText: String, repsText: String, rpe: Double?) async {
        guard updateRow(setId: setId, save: true, mutation: { row in
            row.weightText = weightText
            row.repsText = repsText
            row.rpe = rpe
        }) else {
            transientError = .notFound
            return
        }
        await updateWorkoutLiveActivity()
    }

    func updateWeightUnit(_ unit: WeightUnit) {
        let oldUnit = weightUnit
        guard oldUnit != unit else { return }
        weightUnit = unit
        convertLastSessionReferences(from: oldUnit, to: unit)

        guard case var .success(data) = state else { return }
        for sectionIndex in data.exerciseSections.indices {
            for rowIndex in data.exerciseSections[sectionIndex].sets.indices {
                data.exerciseSections[sectionIndex].sets[rowIndex].weightText = WeightUnit.convertDisplayText(
                    data.exerciseSections[sectionIndex].sets[rowIndex].weightText,
                    from: oldUnit,
                    to: unit
                )
            }
        }
        state = .success(data)
        saveBackup()
    }

    func completeSet(setId: UUID) async {
        guard let row = rowState(setId: setId) else {
            transientError = .notFound
            return
        }
        guard makeWorkoutSet(from: row) != nil else {
            transientError = .validation(.invalidInput)
            return
        }

        markSetCompletedAndCarryForward(setId: setId, sourceRow: row)
        checkBaselineRegained(row: row)
        checkOverloadSuggestionOutcome(row: row)
        if let targetRestSeconds = row.targetRestSeconds, targetRestSeconds > 0 {
            await startRestTimer(seconds: targetRestSeconds, sourceSetId: setId)
        } else {
            await updateWorkoutLiveActivity()
        }
    }

    func addSet(after setId: UUID) async {
        guard case var .success(data) = state else {
            transientError = .notFound
            return
        }
        guard let sectionIndex = data.exerciseSections.firstIndex(where: { section in
            section.sets.contains { $0.id == setId }
        }) else {
            transientError = .notFound
            return
        }
        let sourceRow = data.exerciseSections[sectionIndex].sets.first { $0.id == setId }
        let nextSetNumber = data.exerciseSections[sectionIndex].sets.count + 1
        let newRow = WorkoutSetRowState(
            id: UUID(),
            exerciseId: data.exerciseSections[sectionIndex].programExercise.exerciseId,
            programExerciseId: data.exerciseSections[sectionIndex].programExercise.id,
            setNumber: nextSetNumber,
            weightText: sourceRow?.weightText ?? "",
            repsText: sourceRow?.repsText ?? "\(data.exerciseSections[sectionIndex].programExercise.targetRepsMin)",
            rpe: sourceRow?.rpe,
            targetRestSeconds: data.exerciseSections[sectionIndex].programExercise.targetRestSeconds,
            isCompleted: false
        )
        data.exerciseSections[sectionIndex].sets.append(newRow)
        data.exerciseSections[sectionIndex].sets = renumbered(data.exerciseSections[sectionIndex].sets)
        state = .success(data)
        await updateWorkoutLiveActivity()
        saveBackup()
    }

    func goToExercise(index: Int) {
        guard case var .success(data) = state, data.exerciseSections.isEmpty == false else {
            transientError = .notFound
            return
        }
        data.currentExerciseIndex = min(max(index, 0), data.exerciseSections.count - 1)
        state = .success(data)
        Task { await updateWorkoutLiveActivity() }
        saveBackup()
    }

    func finishExercise(programExerciseId: UUID) async {
        guard case var .success(data) = state else {
            transientError = .notFound
            return
        }
        guard let sectionIndex = data.exerciseSections.firstIndex(where: { $0.programExercise.id == programExerciseId }) else {
            transientError = .notFound
            return
        }
        data.exerciseSections[sectionIndex].isFinished = true
        data.exerciseSections[sectionIndex].finishedAt = now()
        data.currentExerciseIndex = nextUnfinishedExerciseIndex(after: sectionIndex, in: data) ?? sectionIndex
        state = .success(data)
        await updateWorkoutLiveActivity()
        saveBackup()
    }

    func deleteSet(setId: UUID) async {
        guard case var .success(data) = state else {
            transientError = .notFound
            return
        }
        guard data.exerciseSections.contains(where: { section in
            section.sets.contains { $0.id == setId }
        }), let sectionIndex = data.exerciseSections.firstIndex(where: { section in
            section.sets.contains { $0.id == setId }
        }) else {
            transientError = .notFound
            return
        }

        data.exerciseSections[sectionIndex].sets.removeAll { $0.id == setId }
        data.exerciseSections[sectionIndex].sets = renumbered(data.exerciseSections[sectionIndex].sets)
        state = .success(data)
        await updateWorkoutLiveActivity()
        saveBackup()
    }

    func startRestTimer(seconds: Int, sourceSetId: UUID) async {
        let startedAt = now()
        let timer = RestTimerState(
            sourceSetId: sourceSetId,
            targetSeconds: seconds,
            startedAt: startedAt,
            endsAt: startedAt.addingTimeInterval(TimeInterval(seconds))
        )
        activeTimer = timer
        saveBackup()

        let context = restTimerContext(sourceSetId: sourceSetId)
        await restTimerScheduler.requestAuthorizationIfNeeded()
        await restTimerScheduler.schedule(
            after: TimeInterval(seconds),
            sessionId: context.sessionId,
            programDayId: context.programDayId,
            programExerciseId: context.programExerciseId
        )
        await updateWorkoutLiveActivity()
    }

    func stopRestTimer() {
        if let activeTimer {
            let context = restTimerContext(sourceSetId: activeTimer.sourceSetId)
            restTimerScheduler.cancel(sessionId: context.sessionId)
        }
        activeTimer = nil
        saveBackup()
        Task { await updateWorkoutLiveActivity() }
    }

    func markRestTimerComplete() async {
        await updateWorkoutLiveActivity(phase: .ready)
    }

    func prepareForScreenExit() {
        saveBackup()
    }

    func finishSession() async {
        guard case let .success(data) = state else {
            workoutLogger.error("finishSession-blocked: state is not success")
            transientError = .notFound
            return
        }
        guard isFinishing == false else { return }
        guard data.exerciseSections.isEmpty == false,
              data.exerciseSections.allSatisfy(\.isFinished) else {
            let unfinished = data.exerciseSections.filter { !$0.isFinished }.map { $0.programExercise.id.uuidString }
            workoutLogger.error("finishSession-blocked: exercises not finished: \(unfinished.joined(separator: ", "))")
            transientError = .validation(.missingRequiredField)
            return
        }

        isFinishing = true
        defer { isFinishing = false }

        let completedRows = data.exerciseSections.flatMap(\.sets).filter(\.isCompleted)
        let endedAt = now()
        var sessionToInsert = data.session
        sessionToInsert.endedAt = endedAt

        // Step 1: Insert the completed session. Nothing has touched the DB yet,
        // so a failure here leaves zero orphan data.
        do {
            workoutLogger.debug("finishSession: inserting session sessionId=\(data.session.id)")
            try await workoutRepository.insertSession(sessionToInsert)
            workoutLogger.debug("finishSession: insertSession succeeded")
        } catch {
            let mapped = appError(error, operation: "insertWorkoutSession")
            workoutLogger.error("finishSession-blocked: insertSession failed error=\(String(describing: mapped))")
            transientError = mapped.visibleOrNil
            saveBackup()
            return
        }

        // Step 2: Upload sets (FK satisfied because session now exists).
        // On any failure, best-effort rollback the session so we don't leave
        // a completed-looking row with missing sets.
        for row in completedRows {
            guard let set = makeWorkoutSet(from: row) else {
                workoutLogger.warning("finishSession: skipping setId=\(row.id) — invalid text (weight='\(row.weightText)' reps='\(row.repsText)')")
                continue
            }
            do {
                try await upload(set)
            } catch {
                let mapped = appError(error, operation: "uploadWorkoutSet")
                workoutLogger.error("finishSession-blocked: upload failed for setId=\(row.id) error=\(String(describing: mapped))")
                try? await workoutRepository.deleteSession(id: data.session.id)
                transientError = mapped.visibleOrNil
                saveBackup()
                return
            }
        }

        // Step 3: Full success — clear local backup, tear down live activity.
        backupRepository.clearBackup()
        activeTimer = nil
        restTimerScheduler.cancelAll()
        await liveActivityController.end()
        updateSessionEndedAt(endedAt)
        if isComebackMode {
            analytics.track(.comebackSessionFinished)
        }
    }

    private func startWorkoutLiveActivity() async {
        guard case let .success(data) = state,
              let activityState = workoutActivityState(in: data) else {
            return
        }
        await liveActivityController.start(
            sessionId: data.session.id,
            programDayId: data.session.programDayId,
            state: activityState
        )
    }

    private func updateWorkoutLiveActivity(
        phase: RestTimerActivityAttributes.Phase? = nil
    ) async {
        guard case let .success(data) = state,
              let activityState = workoutActivityState(in: data, phase: phase) else {
            return
        }
        await liveActivityController.update(activityState)
    }

    private func workoutActivityState(
        in data: WorkoutSessionData,
        phase overridePhase: RestTimerActivityAttributes.Phase? = nil
    ) -> RestTimerActivityAttributes.ContentState? {
        let phase = overridePhase ?? workoutActivityPhase()
        let currentWork = activeTimer.flatMap { workState(forSetId: $0.sourceSetId, in: data) }
            ?? currentWorkState(in: data)
        let nextWork = activeTimer.flatMap { nextWorkState(afterSetId: $0.sourceSetId, in: data) }

        guard currentWork != nil || nextWork != nil else { return nil }

        return RestTimerActivityAttributes.ContentState(
            phase: phase,
            workoutName: data.day.name,
            workoutStartedAt: data.session.startedAt,
            currentWork: currentWork,
            nextWork: nextWork,
            restStartedAt: activeTimer?.startedAt,
            restEndsAt: phase == .active ? nil : activeTimer?.endsAt
        )
    }

    private func workoutActivityPhase() -> RestTimerActivityAttributes.Phase {
        guard let activeTimer else { return .active }
        return activeTimer.remainingSeconds(at: now()) <= 0 ? .ready : .resting
    }

    private func currentWorkState(in data: WorkoutSessionData) -> RestTimerActivityAttributes.WorkState? {
        guard data.exerciseSections.isEmpty == false else { return nil }
        let clampedIndex = min(max(data.currentExerciseIndex, 0), data.exerciseSections.count - 1)
        let currentSection = data.exerciseSections[clampedIndex]
        if let work = nextIncompleteWorkState(in: currentSection) {
            return work
        }
        return data.exerciseSections
            .filter { $0.isFinished == false }
            .compactMap { nextIncompleteWorkState(in: $0) }
            .first
    }

    private func workState(
        forSetId setId: UUID,
        in data: WorkoutSessionData
    ) -> RestTimerActivityAttributes.WorkState? {
        for section in data.exerciseSections {
            guard let row = section.sets.first(where: { $0.id == setId }) else { continue }
            return workState(from: row, in: section)
        }
        return nil
    }

    private func nextWorkState(
        afterSetId setId: UUID,
        in data: WorkoutSessionData
    ) -> RestTimerActivityAttributes.WorkState? {
        guard let sectionIndex = data.exerciseSections.firstIndex(where: { section in
            section.sets.contains { $0.id == setId }
        }), let rowIndex = data.exerciseSections[sectionIndex].sets.firstIndex(where: { $0.id == setId }) else {
            return currentWorkState(in: data)
        }

        let section = data.exerciseSections[sectionIndex]
        let followingRows = section.sets[section.sets.index(after: rowIndex)..<section.sets.endIndex]
        if let nextRow = followingRows.first(where: { $0.isCompleted == false }) {
            return workState(from: nextRow, in: section)
        }

        let followingSections = data.exerciseSections[data.exerciseSections.index(after: sectionIndex)..<data.exerciseSections.endIndex]
        if let next = followingSections
            .filter({ $0.isFinished == false })
            .compactMap({ nextIncompleteWorkState(in: $0) })
            .first {
            return next
        }

        return data.exerciseSections[..<sectionIndex]
            .filter { $0.isFinished == false }
            .compactMap { nextIncompleteWorkState(in: $0) }
            .first
    }

    private func nextIncompleteWorkState(
        in section: WorkoutExerciseSection
    ) -> RestTimerActivityAttributes.WorkState? {
        guard section.isFinished == false,
              let row = section.sets.first(where: { $0.isCompleted == false }) else {
            return nil
        }
        return workState(from: row, in: section)
    }

    private func workState(
        from row: WorkoutSetRowState,
        in section: WorkoutExerciseSection
    ) -> RestTimerActivityAttributes.WorkState {
        RestTimerActivityAttributes.WorkState(
            programExerciseId: section.programExercise.id,
            exerciseName: section.exercise?.name ?? String(localized: "workout.exercise.unknownExercise"),
            weightText: weightText(for: row),
            setNumber: row.setNumber,
            totalSets: max(section.sets.count, section.programExercise.targetSets),
            repsText: repsText(for: row, in: section)
        )
    }

    private func weightText(for row: WorkoutSetRowState) -> String? {
        let draftWeight = row.weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard draftWeight.isEmpty == false else { return nil }
        return "\(draftWeight) \(weightUnit.localizedAbbreviation)"
    }

    private func repsText(
        for row: WorkoutSetRowState,
        in section: WorkoutExerciseSection
    ) -> String {
        let draftReps = row.repsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if draftReps.isEmpty == false {
            return String(format: String(localized: "workout.live_activity.reps"), draftReps)
        }
        return String(
            format: String(localized: "programExercise.repsFormat"),
            section.programExercise.targetRepsMin,
            section.programExercise.targetRepsMax
        )
    }

    private func makeInitialRows(
        from programExercises: [ProgramExercise],
        defaultWeights: [UUID: Double]
    ) -> [WorkoutSetRowState] {
        programExercises.flatMap { programExercise in
            let setCount = recommendation.adjustments[programExercise.id]?.adjustedSets ?? programExercise.targetSets
            return (1...max(setCount, 1)).map { setNumber in
                WorkoutSetRowState(
                    id: UUID(),
                    exerciseId: programExercise.exerciseId,
                    programExerciseId: programExercise.id,
                    setNumber: setNumber,
                    weightText: setNumber == 1 ? formatWeight(defaultWeights[programExercise.id]) : "",
                    repsText: setNumber == 1 ? "\(programExercise.targetRepsMin)" : "",
                    rpe: nil,
                    targetRestSeconds: programExercise.targetRestSeconds,
                    isCompleted: false
                )
            }
        }
    }

    private func resolveDefaultWeights(
        for programExercises: [ProgramExercise],
        before date: Date
    ) async -> [UUID: Double] {
        var defaultWeights: [UUID: Double] = [:]
        for programExercise in programExercises {
            if let adjustedWeight = recommendation.adjustments[programExercise.id]?.adjustedTargetWeight {
                defaultWeights[programExercise.id] = adjustedWeight
                continue
            }
            if let targetWeight = programExercise.targetWeight {
                defaultWeights[programExercise.id] = targetWeight
                continue
            }
            do {
                if let lastSet = try await workoutRepository.fetchLastLoggedSet(
                    exerciseId: programExercise.exerciseId,
                    before: date
                ) {
                    defaultWeights[programExercise.id] = lastSet.weight
                }
            } catch {
                workoutLogger.debug("Failed to resolve last logged weight: \(String(describing: error))")
            }
        }
        return defaultWeights
    }

    private func buildLastSessionReferences() async {
        guard case let .success(data) = state else { return }

        do {
            let history = try await workoutRepository.fetchHistory(limit: 10)
            var setsBySessionId: [UUID: [WorkoutSet]] = [:]
            for session in history {
                setsBySessionId[session.id] = try await workoutRepository.fetchSets(sessionId: session.id)
            }

            var references: [UUID: LastSessionReference] = [:]
            for section in data.exerciseSections {
                if let reference = lastSessionLookupService.reference(
                    for: section.programExercise.id,
                    exerciseId: section.programExercise.exerciseId,
                    in: history,
                    sets: setsBySessionId,
                    unit: weightUnit
                ) {
                    references[section.programExercise.id] = reference
                }
            }
            lastSessionReferences = applyingBaselineReferences(to: references)
        } catch {
            let mapped = appError(error, operation: "buildLastSessionReferences")
            workoutLogger.debug("Failed to build last-session references: \(String(describing: mapped))")
            lastSessionReferences = applyingBaselineReferences(to: [:])
        }
    }

    /// In comeback mode the reference row shows the pre-gap baseline instead of the last session.
    private func applyingBaselineReferences(
        to references: [UUID: LastSessionReference]
    ) -> [UUID: LastSessionReference] {
        guard isComebackMode, case let .success(data) = state else { return references }

        var updated = references
        for section in data.exerciseSections {
            guard let adjustment = recommendation.adjustments[section.programExercise.id],
                  let baselineWeight = adjustment.baselineWeight,
                  adjustment.baselineReps.isEmpty == false else {
                continue
            }
            updated[section.programExercise.id] = LastSessionReference(
                label: .baseline,
                sets: adjustment.baselineReps.map { reps in
                    LastSessionReference.SetSummary(
                        weight: weightUnit.displayValue(fromKilograms: baselineWeight),
                        reps: reps
                    )
                },
                unit: weightUnit,
                isFallback: false
            )
        }
        return updated
    }

    private func checkBaselineRegained(row: WorkoutSetRowState) {
        guard isComebackMode,
              baselineRegainedThisSession == false,
              let programExerciseId = row.programExerciseId,
              let adjustment = recommendation.adjustments[programExerciseId],
              let baselineWeight = adjustment.baselineWeight,
              let baselineReps = adjustment.baselineReps.first,
              let weightKg = weightUnit.kilogramValue(fromDisplayText: row.weightText),
              let reps = Int(row.repsText.trimmingCharacters(in: .whitespacesAndNewlines)),
              weightKg >= baselineWeight,
              reps >= baselineReps else {
            return
        }
        baselineRegainedThisSession = true
        playBaselineRegainedHaptic()
        analytics.track(.comebackExitBaselineReached)
    }

    /// Resolves the outcome of an Overload Advisor bump the first time this session logs an
    /// RPE for the flagged exercise: RPE < 9 quietly confirms the new weight, RPE >= 9 asks
    /// the user whether to keep it or revert to what they lifted before the bump.
    private func checkOverloadSuggestionOutcome(row: WorkoutSetRowState) {
        guard let programExerciseId = row.programExerciseId,
              overloadOutcomesHandled.contains(programExerciseId) == false,
              case let .success(data) = state,
              let section = data.exerciseSections.first(where: { $0.programExercise.id == programExerciseId }),
              let previousWeight = section.pendingOverloadPreviousWeight,
              let rpe = row.rpe else {
            return
        }

        overloadOutcomesHandled.insert(programExerciseId)

        guard rpe >= 9 else {
            overloadSuggestionTracker.clearSuggestion(programExerciseId: programExerciseId)
            return
        }

        overloadOutcomePrompt = OverloadOutcomePrompt(
            id: programExerciseId,
            programExercise: section.programExercise,
            exerciseName: section.exercise?.displayName ?? String(localized: "workout.exercise.unknownExercise"),
            newWeight: section.programExercise.targetWeight ?? previousWeight,
            previousWeight: previousWeight
        )
    }

    func keepNewOverloadWeight() {
        guard let prompt = overloadOutcomePrompt else { return }
        overloadSuggestionTracker.clearSuggestion(programExerciseId: prompt.programExercise.id)
        overloadOutcomePrompt = nil
    }

    func revertOverloadWeight() async {
        guard let prompt = overloadOutcomePrompt else { return }
        overloadOutcomePrompt = nil
        overloadSuggestionTracker.clearSuggestion(programExerciseId: prompt.programExercise.id)

        var updated = prompt.programExercise
        updated.targetWeight = prompt.previousWeight
        do {
            _ = try await programRepository.updateProgramExercise(updated)
        } catch {
            let appError = appError(error, operation: "revertOverloadWeight")
            if appError != .cancelled {
                transientError = appError
            }
        }
    }

    private func upload(_ set: WorkoutSet) async throws {
        do {
            _ = try await workoutRepository.uploadSet(set)
        } catch {
            let mapped = appError(error, operation: "uploadWorkoutSet")
            if mapped == .conflict {
                try await updateExistingSet(set)
                return
            }
            throw mapped
        }
    }

    private func updateExistingSet(_ set: WorkoutSet) async throws {
        do {
            _ = try await workoutRepository.updateSet(set)
        } catch {
            let mapped = appError(error, operation: "updateWorkoutSetAfterConflict")
            workoutLogger.error("updateExistingSet-failed: setId=\(set.id) error=\(String(describing: mapped))")
            throw mapped
        }
    }

    private func makeWorkoutSet(from row: WorkoutSetRowState) -> WorkoutSet? {
        guard case let .success(data) = state,
              let weight = weightUnit.kilogramValue(fromDisplayText: row.weightText),
              let reps = Int(row.repsText.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...100).contains(reps) else {
            return nil
        }
        if let rpe = row.rpe, (AppConstants.Workout.minRPE...AppConstants.Workout.maxRPE).contains(rpe) == false {
            return nil
        }

        return WorkoutSet(
            id: row.id,
            sessionId: data.session.id,
            exerciseId: row.exerciseId,
            programExerciseId: row.programExerciseId,
            setNumber: row.setNumber,
            weight: weight,
            reps: reps,
            rpe: row.rpe,
            targetRestSeconds: row.targetRestSeconds,
            actualRestSeconds: nil,
            restStartedAt: nil,
            restEndedAt: nil,
            completedAt: now(),
            notes: nil
        )
    }

    private func setSuccess(
        session: WorkoutSession,
        day: ProgramDay,
        programExercises: [ProgramExercise],
        exerciseLookup: [UUID: Exercise],
        rowStates: [WorkoutSetRowState],
        startedAt: Date,
        currentExerciseIndex: Int,
        finishedExerciseIds: Set<UUID>,
        defaultWeights: [UUID: Double]
    ) {
        let rowsByProgramExerciseId = Dictionary(grouping: rowStates) { $0.programExerciseId }
        let sections = programExercises.map { programExercise in
            WorkoutExerciseSection(
                programExercise: programExercise,
                exercise: exerciseLookup[programExercise.exerciseId],
                sets: renumbered(rowsByProgramExerciseId[programExercise.id] ?? []),
                isFinished: finishedExerciseIds.contains(programExercise.id),
                finishedAt: nil,
                defaultWeight: defaultWeights[programExercise.id],
                pendingOverloadPreviousWeight: overloadSuggestionTracker.pendingPreviousWeight(
                    programExerciseId: programExercise.id
                )
            )
        }
        state = .success(WorkoutSessionData(
            session: session,
            day: day,
            exerciseSections: sections,
            exerciseLookup: exerciseLookup,
            startedAt: startedAt,
            currentExerciseIndex: sections.isEmpty ? 0 : min(max(currentExerciseIndex, 0), sections.count - 1)
        ))
    }

    private func saveBackup() {
        guard case let .success(data) = state else { return }
        guard data.session.endedAt == nil else { return }
        let snapshot = ActiveSessionSnapshot(
            session: data.session,
            day: data.day,
            programExercises: data.exerciseSections.map(\.programExercise),
            exerciseLookup: data.exerciseLookup,
            rowStates: data.exerciseSections.flatMap(\.sets).map(ActiveSessionSetSnapshot.init(rowState:)),
            activeTimer: activeTimer,
            finishedExerciseIds: data.exerciseSections.filter(\.isFinished).map(\.programExercise.id),
            currentExerciseIndex: data.currentExerciseIndex,
            defaultWeights: Dictionary(uniqueKeysWithValues: data.exerciseSections.compactMap { section in
                section.defaultWeight.map { (section.programExercise.id, $0) }
            }),
            updatedAt: now()
        )
        if case .failure(let error) = backupRepository.saveBackup(snapshot) {
            workoutLogger.error("Failed to save active session backup: \(String(describing: error))")
            transientError = error.visibleOrNil
        }
    }

    private func restTimerContext(sourceSetId: UUID) -> (
        sessionId: UUID,
        programDayId: UUID?,
        programExerciseId: UUID?,
        exerciseName: String
    ) {
        guard case let .success(data) = state else {
            return (UUID(), nil, nil, String(localized: "workout.timer.rest"))
        }

        for section in data.exerciseSections where section.sets.contains(where: { $0.id == sourceSetId }) {
            return (
                data.session.id,
                data.session.programDayId,
                section.programExercise.id,
                section.exercise?.name ?? String(localized: "workout.exercise.unknownExercise")
            )
        }

        return (
            data.session.id,
            data.session.programDayId,
            nil,
            String(localized: "workout.timer.rest")
        )
    }

    private func convertLastSessionReferences(from oldUnit: WeightUnit, to newUnit: WeightUnit) {
        guard oldUnit != newUnit else { return }
        lastSessionReferences = lastSessionReferences.mapValues { reference in
            var updated = reference
            updated.sets = reference.sets.map { set in
                var updatedSet = set
                if let weight = set.weight {
                    let kilograms = oldUnit.kilograms(fromDisplayValue: weight)
                    updatedSet.weight = newUnit.displayValue(fromKilograms: kilograms)
                }
                return updatedSet
            }
            updated.unit = newUnit
            return updated
        }
    }

    @discardableResult
    private func updateRow(
        setId: UUID,
        save: Bool,
        mutation: (inout WorkoutSetRowState) -> Void
    ) -> Bool {
        guard case var .success(data) = state else { return false }
        for sectionIndex in data.exerciseSections.indices {
            guard let rowIndex = data.exerciseSections[sectionIndex].sets.firstIndex(where: { $0.id == setId }) else {
                continue
            }
            mutation(&data.exerciseSections[sectionIndex].sets[rowIndex])
            state = .success(data)
            if save {
                saveBackup()
            }
            return true
        }
        return false
    }

    private func updateSessionEndedAt(_ endedAt: Date) {
        guard case var .success(data) = state else { return }
        data.session.endedAt = endedAt
        state = .success(data)
    }

    private func rowState(setId: UUID) -> WorkoutSetRowState? {
        guard case let .success(data) = state else { return nil }
        return data.exerciseSections.flatMap(\.sets).first { $0.id == setId }
    }

    private func markSetCompletedAndCarryForward(setId: UUID, sourceRow: WorkoutSetRowState) {
        guard case var .success(data) = state else { return }
        for sectionIndex in data.exerciseSections.indices {
            guard let rowIndex = data.exerciseSections[sectionIndex].sets.firstIndex(where: { $0.id == setId }) else {
                continue
            }
            data.exerciseSections[sectionIndex].sets[rowIndex].isCompleted = true

            if let nextIndex = data.exerciseSections[sectionIndex].sets[
                data.exerciseSections[sectionIndex].sets.index(after: rowIndex)..<data.exerciseSections[sectionIndex].sets.endIndex
            ].firstIndex(where: { $0.isCompleted == false }),
               shouldCarryForward(to: data.exerciseSections[sectionIndex].sets[nextIndex], in: data.exerciseSections[sectionIndex]) {
                data.exerciseSections[sectionIndex].sets[nextIndex].weightText = sourceRow.weightText
                data.exerciseSections[sectionIndex].sets[nextIndex].repsText = sourceRow.repsText
            }

            state = .success(data)
            saveBackup()
            return
        }
    }

    private func shouldCarryForward(to row: WorkoutSetRowState, in section: WorkoutExerciseSection) -> Bool {
        let isBlank = row.weightText.isEmpty && row.repsText.isEmpty
        let matchesInitial = row.weightText == initialWeightText(for: row, in: section)
            && row.repsText == initialRepsText(for: row, in: section)
        return isBlank || matchesInitial
    }

    private func initialWeightText(for row: WorkoutSetRowState, in section: WorkoutExerciseSection) -> String {
        row.setNumber == 1 ? formatWeight(section.defaultWeight) : ""
    }

    private func initialRepsText(for row: WorkoutSetRowState, in section: WorkoutExerciseSection) -> String {
        row.setNumber == 1 ? "\(section.programExercise.targetRepsMin)" : ""
    }

    private func moveToFirstUnfinishedExercise() {
        guard case var .success(data) = state,
              let firstUnfinishedIndex = data.exerciseSections.firstIndex(where: { $0.isFinished == false }) else {
            return
        }
        data.currentExerciseIndex = firstUnfinishedIndex
        state = .success(data)
    }

    private func nextUnfinishedExerciseIndex(after index: Int, in data: WorkoutSessionData) -> Int? {
        let followingIndex = data.exerciseSections.index(after: index)
        if followingIndex < data.exerciseSections.endIndex,
           let next = data.exerciseSections[followingIndex...].firstIndex(where: { $0.isFinished == false }) {
            return next
        }
        return data.exerciseSections.firstIndex(where: { $0.isFinished == false })
    }

    private func renumbered(_ rows: [WorkoutSetRowState]) -> [WorkoutSetRowState] {
        rows.enumerated().map { index, row in
            var updated = row
            updated.setNumber = index + 1
            return updated
        }
    }

    private func appError(_ error: Error, operation: String) -> AppError {
        ErrorMapper.map(error, context: .init(operation: operation))
    }

    private func formatWeight(_ value: Double?) -> String {
        guard let value else { return "" }
        return weightUnit.formattedKilograms(value, fractionLength: 0...2)
    }
}

private extension AppError {
    var visibleOrNil: AppError? {
        isVisibleToUser ? self : nil
    }
}

private extension WorkoutSetRowState {
    init(snapshot: ActiveSessionSetSnapshot) {
        self.init(
            id: snapshot.id,
            exerciseId: snapshot.exerciseId,
            programExerciseId: snapshot.programExerciseId,
            setNumber: snapshot.setNumber,
            weightText: snapshot.weightText,
            repsText: snapshot.repsText,
            rpe: snapshot.rpe,
            targetRestSeconds: snapshot.targetRestSeconds,
            isCompleted: snapshot.isCompleted
        )
    }
}

private extension ActiveSessionSetSnapshot {
    init(rowState: WorkoutSetRowState) {
        self.init(
            id: rowState.id,
            exerciseId: rowState.exerciseId,
            programExerciseId: rowState.programExerciseId,
            setNumber: rowState.setNumber,
            weightText: rowState.weightText,
            repsText: rowState.repsText,
            rpe: rowState.rpe,
            targetRestSeconds: rowState.targetRestSeconds,
            isCompleted: rowState.isCompleted
        )
    }
}
