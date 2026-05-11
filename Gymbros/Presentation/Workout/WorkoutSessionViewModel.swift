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

    private let workoutRepository: WorkoutRepositoryProviding
    private let programRepository: ProgramRepositoryProviding
    private let exerciseRepository: ExerciseRepositoryProviding
    private let backupRepository: ActiveSessionBackupRepositoryProviding
    private let now: () -> Date

    init(
        workoutRepository: WorkoutRepositoryProviding? = nil,
        programRepository: ProgramRepositoryProviding? = nil,
        exerciseRepository: ExerciseRepositoryProviding? = nil,
        backupRepository: ActiveSessionBackupRepositoryProviding? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.workoutRepository = workoutRepository ?? WorkoutRepository()
        self.programRepository = programRepository ?? ProgramRepository()
        self.exerciseRepository = exerciseRepository ?? ExerciseRepository()
        self.backupRepository = backupRepository ?? ActiveSessionBackupRepository()
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
            let rowStates = Self.makeInitialRows(from: orderedProgramExercises)
            setSuccess(
                session: session,
                day: day,
                programExercises: orderedProgramExercises,
                exerciseLookup: exerciseLookup,
                rowStates: rowStates,
                startedAt: startedAt
            )
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
        setSuccess(
            session: snapshot.session,
            day: snapshot.day,
            programExercises: snapshot.programExercises,
            exerciseLookup: snapshot.exerciseLookup,
            rowStates: snapshot.rowStates.map(WorkoutSetRowState.init(snapshot:)),
            startedAt: snapshot.session.startedAt
        )
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
            if row.isCompleted {
                row.syncState = .pending
            }
        }) else {
            transientError = .notFound
            return
        }
    }

    func completeSet(setId: UUID) async {
        guard let row = rowState(setId: setId) else {
            transientError = .notFound
            return
        }
        guard let set = makeWorkoutSet(from: row) else {
            transientError = .validation(.invalidInput)
            return
        }

        updateRow(setId: setId, save: true) { row in
            row.isCompleted = true
            row.syncState = .uploading
        }
        if let targetRestSeconds = row.targetRestSeconds, targetRestSeconds > 0 {
            startRestTimer(seconds: targetRestSeconds, sourceSetId: setId)
        }
        await upload(set, setId: setId)
    }

    func retryUpload(setId: UUID) async {
        guard let row = rowState(setId: setId) else {
            transientError = .notFound
            return
        }
        guard let set = makeWorkoutSet(from: row) else {
            transientError = .validation(.invalidInput)
            return
        }

        updateRow(setId: setId, save: true) { row in
            row.syncState = .uploading
            row.isCompleted = true
        }
        await upload(set, setId: setId)
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
            syncState: .pending,
            isCompleted: false
        )
        data.exerciseSections[sectionIndex].sets.append(newRow)
        data.exerciseSections[sectionIndex].sets = renumbered(data.exerciseSections[sectionIndex].sets)
        state = .success(data)
        saveBackup()
    }

    func deleteSet(setId: UUID) async {
        guard case var .success(data) = state else {
            transientError = .notFound
            return
        }
        guard let sectionIndex = data.exerciseSections.firstIndex(where: { section in
            section.sets.contains { $0.id == setId }
        }), let row = data.exerciseSections[sectionIndex].sets.first(where: { $0.id == setId }) else {
            transientError = .notFound
            return
        }

        if row.isCompleted, row.syncState == .uploaded {
            do {
                try await workoutRepository.deleteSet(id: setId)
            } catch {
                transientError = appError(error, operation: "deleteWorkoutSet").visibleOrNil
                return
            }
        }

        data.exerciseSections[sectionIndex].sets.removeAll { $0.id == setId }
        data.exerciseSections[sectionIndex].sets = renumbered(data.exerciseSections[sectionIndex].sets)
        state = .success(data)
        saveBackup()
    }

    func startRestTimer(seconds: Int, sourceSetId: UUID) {
        let startedAt = now()
        activeTimer = RestTimerState(
            sourceSetId: sourceSetId,
            targetSeconds: seconds,
            startedAt: startedAt,
            endsAt: startedAt.addingTimeInterval(TimeInterval(seconds))
        )
        saveBackup()
    }

    func stopRestTimer() {
        activeTimer = nil
        saveBackup()
    }

    func finishSession() async {
        guard case let .success(data) = state else {
            transientError = .notFound
            return
        }
        guard isFinishing == false else { return }
        guard data.exerciseSections.flatMap(\.sets).contains(where: { $0.isCompleted }) else {
            transientError = .validation(.missingRequiredField)
            return
        }

        isFinishing = true
        defer { isFinishing = false }

        let uploadableRows = data.exerciseSections
            .flatMap(\.sets)
            .filter { $0.isCompleted && $0.syncState != .uploaded }

        for row in uploadableRows {
            guard let set = makeWorkoutSet(from: row) else {
                transientError = .validation(.invalidInput)
                return
            }
            updateRow(setId: row.id, save: true) { $0.syncState = .uploading }
            await upload(set, setId: row.id)
            if case .failed = rowState(setId: row.id)?.syncState {
                return
            }
        }

        do {
            try await workoutRepository.completeSession(data.session.id, endedAt: now())
            backupRepository.clearBackup()
            activeTimer = nil
            updateSessionEndedAt(now())
        } catch {
            transientError = appError(error, operation: "finishWorkoutSession").visibleOrNil
            saveBackup()
        }
    }

    private static func makeInitialRows(from programExercises: [ProgramExercise]) -> [WorkoutSetRowState] {
        programExercises.flatMap { programExercise in
            (1...max(programExercise.targetSets, 1)).map { setNumber in
                WorkoutSetRowState(
                    id: UUID(),
                    exerciseId: programExercise.exerciseId,
                    programExerciseId: programExercise.id,
                    setNumber: setNumber,
                    weightText: "",
                    repsText: "\(programExercise.targetRepsMin)",
                    rpe: nil,
                    targetRestSeconds: programExercise.targetRestSeconds,
                    syncState: .pending,
                    isCompleted: false
                )
            }
        }
    }

    private func upload(_ set: WorkoutSet, setId: UUID) async {
        do {
            _ = try await workoutRepository.uploadSet(set)
            updateRow(setId: setId, save: true) { row in
                row.syncState = .uploaded
                row.isCompleted = true
            }
        } catch {
            let mapped = appError(error, operation: "uploadWorkoutSet")
            updateRow(setId: setId, save: true) { row in
                row.syncState = .failed(mapped)
                row.isCompleted = true
            }
            transientError = mapped.visibleOrNil
        }
    }

    private func makeWorkoutSet(from row: WorkoutSetRowState) -> WorkoutSet? {
        guard case let .success(data) = state,
              let weight = Double(row.weightText.trimmingCharacters(in: .whitespacesAndNewlines)),
              weight >= 0,
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
        startedAt: Date
    ) {
        let rowsByProgramExerciseId = Dictionary(grouping: rowStates) { $0.programExerciseId }
        let sections = programExercises.map { programExercise in
            WorkoutExerciseSection(
                programExercise: programExercise,
                exercise: exerciseLookup[programExercise.exerciseId],
                sets: renumbered(rowsByProgramExerciseId[programExercise.id] ?? [])
            )
        }
        state = .success(WorkoutSessionData(
            session: session,
            day: day,
            exerciseSections: sections,
            exerciseLookup: exerciseLookup,
            startedAt: startedAt
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
            updatedAt: now()
        )
        if case .failure(let error) = backupRepository.saveBackup(snapshot) {
            workoutLogger.error("Failed to save active session backup: \(String(describing: error))")
            transientError = error.visibleOrNil
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
            syncState: WorkoutSetSyncState(snapshot.syncState),
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
            syncState: ActiveSessionSetSyncState(rowState.syncState),
            isCompleted: rowState.isCompleted
        )
    }
}

private extension WorkoutSetSyncState {
    init(_ snapshot: ActiveSessionSetSyncState) {
        switch snapshot {
        case .pending:
            self = .pending
        case .uploading:
            self = .uploading
        case .uploaded:
            self = .uploaded
        case .failed(let error):
            self = .failed(error)
        }
    }
}

private extension ActiveSessionSetSyncState {
    init(_ rowState: WorkoutSetSyncState) {
        switch rowState {
        case .pending:
            self = .pending
        case .uploading:
            self = .uploading
        case .uploaded:
            self = .uploaded
        case .failed(let error):
            self = .failed(error)
        }
    }
}
