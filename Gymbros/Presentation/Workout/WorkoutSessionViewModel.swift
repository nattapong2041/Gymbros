import Foundation
import Observation
import OSLog

private let workoutLogger = Logger(subsystem: "com.nattapongsawa.gymbros", category: "WorkoutSessionViewModel")

@MainActor
@Observable
final class WorkoutSessionViewModel {
    var state: ViewState<WorkoutSessionData> = .idle
    var transientError: AppError?
    var activeTimer: RestTimerState?
    var isFinishing = false
    var pendingRestore: ActiveSessionSnapshot?
    var lastSessionReferences: [UUID: LastSessionReference] = [:]

    private let workoutRepository: WorkoutRepositoryProviding
    private let programRepository: ProgramRepositoryProviding
    private let exerciseRepository: ExerciseRepositoryProviding
    private let backupRepository: ActiveSessionBackupRepositoryProviding
    private let restTimerScheduler: RestTimerScheduling
    private let liveActivityController: RestTimerLiveActivityControlling
    private let lastSessionLookupService: LastSessionLookupService
    private let now: () -> Date
    private var weightUnit: WeightUnit

    init(
        workoutRepository: WorkoutRepositoryProviding? = nil,
        programRepository: ProgramRepositoryProviding? = nil,
        exerciseRepository: ExerciseRepositoryProviding? = nil,
        backupRepository: ActiveSessionBackupRepositoryProviding? = nil,
        restTimerScheduler: RestTimerScheduling? = nil,
        liveActivityController: RestTimerLiveActivityControlling? = nil,
        lastSessionLookupService: LastSessionLookupService = LastSessionLookupService(),
        weightUnit: WeightUnit = .kg,
        now: @escaping () -> Date = Date.init
    ) {
        self.workoutRepository = workoutRepository ?? WorkoutRepository()
        self.programRepository = programRepository ?? ProgramRepository()
        self.exerciseRepository = exerciseRepository ?? ExerciseRepository()
        self.backupRepository = backupRepository ?? ActiveSessionBackupRepository()
        self.restTimerScheduler = restTimerScheduler ?? RestTimerNotificationScheduler()
        self.liveActivityController = liveActivityController ?? RestTimerLiveActivityController()
        self.lastSessionLookupService = lastSessionLookupService
        self.weightUnit = weightUnit
        self.now = now
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
            let session = try await workoutRepository.createSession(programDayId: programDayId, startedAt: startedAt)
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
        saveBackup()
    }

    func discardRestore(_ snapshot: ActiveSessionSnapshot) async {
        if pendingRestore?.session.id == snapshot.session.id {
            pendingRestore = nil
        }
        backupRepository.clearBackup()
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
        if let targetRestSeconds = row.targetRestSeconds, targetRestSeconds > 0 {
            await startRestTimer(seconds: targetRestSeconds, sourceSetId: setId)
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
        saveBackup()
    }

    func goToExercise(index: Int) {
        guard case var .success(data) = state, data.exerciseSections.isEmpty == false else {
            transientError = .notFound
            return
        }
        data.currentExerciseIndex = min(max(index, 0), data.exerciseSections.count - 1)
        state = .success(data)
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
        await liveActivityController.start(
            state: timer,
            sessionId: context.sessionId,
            programDayId: context.programDayId,
            programExerciseId: context.programExerciseId,
            exerciseName: context.exerciseName
        )
    }

    func stopRestTimer() {
        if let activeTimer {
            let context = restTimerContext(sourceSetId: activeTimer.sourceSetId)
            restTimerScheduler.cancel(sessionId: context.sessionId)
        }
        activeTimer = nil
        saveBackup()
        Task { await liveActivityController.end() }
    }

    func markRestTimerComplete() async {
        await liveActivityController.markComplete()
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
                transientError = mapped.visibleOrNil
                saveBackup()
                return
            }
        }

        do {
            workoutLogger.debug("finishSession: calling completeSession sessionId=\(data.session.id)")
            try await workoutRepository.completeSession(data.session.id, endedAt: now())
            workoutLogger.debug("finishSession: completeSession succeeded")
            backupRepository.clearBackup()
            activeTimer = nil
            restTimerScheduler.cancelAll()
            await liveActivityController.end()
            updateSessionEndedAt(now())
        } catch {
            let mapped = appError(error, operation: "finishWorkoutSession")
            workoutLogger.error("finishSession-blocked: completeSession failed error=\(String(describing: mapped))")
            transientError = mapped.visibleOrNil
            saveBackup()
        }
    }

    private func makeInitialRows(
        from programExercises: [ProgramExercise],
        defaultWeights: [UUID: Double]
    ) -> [WorkoutSetRowState] {
        programExercises.flatMap { programExercise in
            (1...max(programExercise.targetSets, 1)).map { setNumber in
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
            lastSessionReferences = references
        } catch {
            let mapped = appError(error, operation: "buildLastSessionReferences")
            workoutLogger.debug("Failed to build last-session references: \(String(describing: mapped))")
            lastSessionReferences = [:]
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
                defaultWeight: defaultWeights[programExercise.id]
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
            if let weight = reference.weight {
                let kilograms = oldUnit.kilograms(fromDisplayValue: weight)
                updated.weight = newUnit.displayValue(fromKilograms: kilograms)
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
