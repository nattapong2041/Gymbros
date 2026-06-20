import Foundation

struct ExerciseAdjustment: Equatable {
    let originalTargetWeight: Double?
    let adjustedTargetWeight: Double?
    let originalSets: Int
    let adjustedSets: Int
    let baselineWeight: Double?
    let baselineReps: [Int]

    var weightMultiplier: Double {
        guard let baselineWeight, baselineWeight > 0, let adjustedTargetWeight else { return 1.0 }
        return adjustedTargetWeight / baselineWeight
    }
}

struct TodayRecommendation: Equatable {
    enum Mode: Equatable {
        case normal
        case comeback(stage: ComebackStage, adjustments: [UUID: ExerciseAdjustment])

        var isComeback: Bool {
            if case .comeback = self { return true }
            return false
        }
    }

    let mode: Mode
    let programDay: ProgramDay?
    let reasonKey: String
    let gapDays: Int
    var rampPreview: [UUID: RampDecision] = [:]
    var overloadHints: [UUID: Double] = [:]

    var adjustments: [UUID: ExerciseAdjustment] {
        if case let .comeback(_, adjustments) = mode { return adjustments }
        return [:]
    }

    var stage: ComebackStage? {
        if case let .comeback(stage, _) = mode { return stage }
        return nil
    }

    static let normalDefault = TodayRecommendation(
        mode: .normal,
        programDay: nil,
        reasonKey: "",
        gapDays: 0
    )
}

struct NextBestSessionEngine {
    static let boundedExitSessionCount = 4

    let advisor: SmartSessionAdvisor
    let ramp: ComebackRampService
    let overload: ProgressiveOverloadEngine

    init(
        advisor: SmartSessionAdvisor = SmartSessionAdvisor(),
        ramp: ComebackRampService = ComebackRampService(),
        overload: ProgressiveOverloadEngine = ProgressiveOverloadEngine()
    ) {
        self.advisor = advisor
        self.ramp = ramp
        self.overload = overload
    }

    // MARK: - Public

    /// Cheap pre-check so callers can skip fetching per-session sets on normal days.
    static func hasGapCandidate(history: [WorkoutSession], now: Date) -> Bool {
        gap(in: completedNewestFirst(history), now: now) != nil
    }

    func recommend(
        program: Program?,
        history: [WorkoutSession],
        sets: [UUID: [WorkoutSet]],
        now: Date
    ) -> TodayRecommendation {
        let completed = Self.completedNewestFirst(history)
        let nextDay = Self.nextDay(from: program, recentHistory: completed)

        guard program != nil,
              completed.isEmpty == false,
              let gap = Self.gap(in: completed, now: now) else {
            return normalResult(
                program: program,
                nextDay: nextDay,
                completed: completed,
                sets: sets,
                now: now
            )
        }

        let stage = advisor.stage(forDaysSinceLast: gap.days)
        guard stage.isComeback else {
            return normalResult(
                program: program,
                nextDay: nextDay,
                completed: completed,
                sets: sets,
                now: now
            )
        }

        let trackedExercises = program.map { $0.days.flatMap(\.exercises) } ?? []
        let state = perExerciseState(for: trackedExercises, completed: completed, sets: sets, gap: gap)
        let postGapSessions = completed.filter { ($0.endedAt ?? $0.startedAt) >= gap.end }.count
        let boundedExit = postGapSessions >= Self.boundedExitSessionCount

        let anyTrackedUnresolved = state.contains { _, exercise in
            exercise.baseline != nil && exercise.isResolved == false
        }

        guard anyTrackedUnresolved, boundedExit == false else {
            return normalResult(
                program: program,
                nextDay: nextDay,
                completed: completed,
                sets: sets,
                now: now
            )
        }

        var adjustments: [UUID: ExerciseAdjustment] = [:]
        var rampPreview: [UUID: RampDecision] = [:]

        for programExercise in trackedExercises {
            let exerciseState = state[programExercise.id]
            adjustments[programExercise.id] = adjustment(
                for: programExercise,
                state: exerciseState,
                stage: stage,
                postGapSessions: postGapSessions
            )
            if postGapSessions >= 1,
               let exerciseState,
               let baseline = exerciseState.baseline,
               exerciseState.isResolved == false {
                rampPreview[programExercise.id] = ramp.decide(
                    lastComebackRPE: exerciseState.lastPostGapRPE,
                    currentWeight: exerciseState.currentWeight ?? baseline.weight * stage.weightMultiplier,
                    baselineWeight: baseline.weight
                )
            }
        }

        return TodayRecommendation(
            mode: .comeback(stage: stage, adjustments: adjustments),
            programDay: nextDay,
            reasonKey: stage.reasonKey,
            gapDays: gap.days,
            rampPreview: rampPreview
        )
    }

    // MARK: - Normal mode

    private func normalResult(
        program: Program?,
        nextDay: ProgramDay?,
        completed: [WorkoutSession],
        sets: [UUID: [WorkoutSet]],
        now: Date
    ) -> TodayRecommendation {
        var overloadHints: [UUID: Double] = [:]
        if sets.isEmpty == false {
            for programExercise in nextDay?.exercises ?? [] {
                if let suggestion = overload.nextWeightSuggestion(
                    forExerciseId: programExercise.exerciseId,
                    recentSessions: completed,
                    sets: sets,
                    targetRepsMin: programExercise.targetRepsMin,
                    now: now
                ) {
                    overloadHints[programExercise.id] = suggestion
                }
            }
        }
        return TodayRecommendation(
            mode: .normal,
            programDay: nextDay,
            reasonKey: "",
            gapDays: 0,
            overloadHints: overloadHints
        )
    }

    // MARK: - Gap detection

    private struct Gap {
        let start: Date
        let end: Date
        let days: Int
    }

    private static func gap(in completed: [WorkoutSession], now: Date) -> Gap? {
        guard let last = completed.first, let lastEnd = last.endedAt else { return nil }

        let daysSinceLast = Int(now.timeIntervalSince(lastEnd) / 86_400)
        if daysSinceLast >= SmartSessionAdvisor.comebackThresholdDays {
            return Gap(start: lastEnd, end: now, days: daysSinceLast)
        }

        for (later, earlier) in zip(completed, completed.dropFirst()) {
            guard let earlierEnd = earlier.endedAt else { continue }
            let spacingDays = Int(later.startedAt.timeIntervalSince(earlierEnd) / 86_400)
            if spacingDays >= SmartSessionAdvisor.comebackThresholdDays {
                return Gap(start: earlierEnd, end: later.startedAt, days: spacingDays)
            }
        }
        return nil
    }

    private static func completedNewestFirst(_ history: [WorkoutSession]) -> [WorkoutSession] {
        history.filter(\.isComplete).sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: - Per-exercise state

    private struct Baseline {
        let weight: Double
        let reps: [Int]
    }

    private struct ExerciseState {
        var baseline: Baseline?
        var currentWeight: Double?
        var lastPostGapRPE: Double?

        var isResolved: Bool {
            guard let baseline else { return true }
            guard let currentWeight, currentWeight >= baseline.weight else { return false }
            guard let lastPostGapRPE else { return true }
            return lastPostGapRPE <= 7.5
        }
    }

    private func perExerciseState(
        for programExercises: [ProgramExercise],
        completed: [WorkoutSession],
        sets: [UUID: [WorkoutSet]],
        gap: Gap
    ) -> [UUID: ExerciseState] {
        var state: [UUID: ExerciseState] = [:]

        for programExercise in programExercises {
            var exerciseState = ExerciseState()

            // Baseline: highest pre-gap working weight + that session's rep scheme.
            for session in completed where (session.endedAt ?? session.startedAt) <= gap.start {
                let exerciseSets = (sets[session.id] ?? [])
                    .filter { $0.programExerciseId == programExercise.id }
                    .sorted { $0.setNumber < $1.setNumber }
                guard let topWeight = exerciseSets.map(\.weight).max() else { continue }
                if exerciseState.baseline == nil || topWeight > exerciseState.baseline!.weight {
                    exerciseState.baseline = Baseline(weight: topWeight, reps: exerciseSets.map(\.reps))
                }
            }

            // Post-gap progress: highest weight since the return + the latest session's top-set RPE.
            var latestPostGapSessionDate: Date?
            for session in completed where (session.endedAt ?? session.startedAt) >= gap.end {
                let exerciseSets = (sets[session.id] ?? [])
                    .filter { $0.programExerciseId == programExercise.id }
                guard let topSet = exerciseSets.max(by: { $0.weight < $1.weight }) else { continue }
                exerciseState.currentWeight = max(exerciseState.currentWeight ?? 0, topSet.weight)
                if latestPostGapSessionDate == nil || session.startedAt > latestPostGapSessionDate! {
                    latestPostGapSessionDate = session.startedAt
                    exerciseState.lastPostGapRPE = topSet.rpe
                }
            }

            state[programExercise.id] = exerciseState
        }
        return state
    }

    private func adjustment(
        for programExercise: ProgramExercise,
        state: ExerciseState?,
        stage: ComebackStage,
        postGapSessions: Int
    ) -> ExerciseAdjustment {
        let originalSets = programExercise.targetSets

        // Untracked (no pre-gap baseline) or already-resolved exercises are never reduced.
        guard let state, let baseline = state.baseline, state.isResolved == false else {
            return ExerciseAdjustment(
                originalTargetWeight: programExercise.targetWeight,
                adjustedTargetWeight: nil,
                originalSets: originalSets,
                adjustedSets: originalSets,
                baselineWeight: state?.baseline?.weight,
                baselineReps: state?.baseline?.reps ?? []
            )
        }

        let adjustedWeight: Double
        if postGapSessions == 0 || state.currentWeight == nil {
            adjustedWeight = baseline.weight * stage.weightMultiplier
        } else {
            let decision = ramp.decide(
                lastComebackRPE: state.lastPostGapRPE,
                currentWeight: state.currentWeight!,
                baselineWeight: baseline.weight
            )
            adjustedWeight = decision == .exitComeback
                ? baseline.weight
                : ramp.applied(decision, to: state.currentWeight!)
        }

        return ExerciseAdjustment(
            originalTargetWeight: programExercise.targetWeight,
            adjustedTargetWeight: adjustedWeight,
            originalSets: originalSets,
            adjustedSets: max(originalSets + stage.setDelta, 1),
            baselineWeight: baseline.weight,
            baselineReps: baseline.reps
        )
    }

    // MARK: - Next day derivation (rotation, same rule as Sprint 4)

    private static func nextDay(from program: Program?, recentHistory: [WorkoutSession]) -> ProgramDay? {
        guard let program, program.days.isEmpty == false else { return nil }

        let sortedDays = program.days.sorted { $0.dayOrder < $1.dayOrder }
        guard let lastSession = recentHistory.first,
              let lastDayId = lastSession.programDayId,
              let lastIndex = sortedDays.firstIndex(where: { $0.id == lastDayId }) else {
            return sortedDays.first
        }
        return sortedDays[(lastIndex + 1) % sortedDays.count]
    }
}
