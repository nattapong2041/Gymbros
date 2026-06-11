import Foundation

struct ActiveWorkoutWidgetData: Equatable {
    enum Status: Equatable {
        case working
        case resting(endsAt: Date)
        case ready
    }

    var status: Status
    var compactStatusText: String
    var workoutName: String
    var exerciseName: String
    var prescriptionText: String
    var route: WorkoutLaunchRoute
    var accessibilityLabel: String

    init?(
        snapshot: ActiveSessionSnapshot,
        weightUnit: WeightUnit,
        date: Date = .now
    ) {
        guard snapshot.session.endedAt == nil,
              let programDayId = snapshot.session.programDayId,
              let work = Self.displayWork(from: snapshot) else {
            return nil
        }

        let status = Self.status(from: snapshot.activeTimer, date: date)
        let prescriptionText = Self.prescriptionText(for: work, weightUnit: weightUnit)
        let compactStatusText = Self.statusText(
            for: status,
            startedAt: snapshot.session.startedAt,
            date: date
        )

        self.status = status
        self.compactStatusText = compactStatusText
        self.workoutName = snapshot.day.name
        self.exerciseName = work.exerciseName
        self.prescriptionText = prescriptionText
        self.route = WorkoutLaunchRoute(
            programDayId: programDayId,
            programExerciseId: work.programExerciseId,
            sessionId: snapshot.session.id
        )
        self.accessibilityLabel = String(
            format: String(localized: "active_workout.accessibility_label"),
            compactStatusText,
            snapshot.day.name,
            work.exerciseName,
            prescriptionText
        )
    }

    private static func status(
        from timer: RestTimerState?,
        date: Date
    ) -> Status {
        guard let timer else { return .working }
        return timer.remainingSeconds(at: date) <= 0 ? .ready : .resting(endsAt: timer.endsAt)
    }

    private static func statusText(
        for status: Status,
        startedAt: Date,
        date: Date
    ) -> String {
        switch status {
        case .working:
            let elapsed = max(0, Int(date.timeIntervalSince(startedAt)))
            return String(
                format: String(localized: "active_workout.status.workout_elapsed"),
                elapsedText(seconds: elapsed)
            )
        case .ready:
            return String(localized: "active_workout.status.ready")
        case .resting(let endsAt):
            let remaining = max(0, Int(ceil(endsAt.timeIntervalSince(date))))
            return String(
                format: String(localized: "active_workout.status.resting_with_time"),
                Self.durationText(seconds: remaining)
            )
        }
    }

    private static func displayWork(from snapshot: ActiveSessionSnapshot) -> ActiveWorkoutWidgetWork? {
        let sections = ActiveWorkoutWidgetSection.makeSections(from: snapshot)
        guard sections.isEmpty == false else { return nil }

        if let timer = snapshot.activeTimer {
            return nextWork(afterSetId: timer.sourceSetId, in: sections)
                ?? work(forSetId: timer.sourceSetId, in: sections)
                ?? currentWork(in: sections, currentExerciseIndex: snapshot.currentExerciseIndex)
        }

        return currentWork(in: sections, currentExerciseIndex: snapshot.currentExerciseIndex)
    }

    private static func currentWork(
        in sections: [ActiveWorkoutWidgetSection],
        currentExerciseIndex: Int
    ) -> ActiveWorkoutWidgetWork? {
        let clampedIndex = min(max(currentExerciseIndex, 0), sections.count - 1)
        if let work = nextIncompleteWork(in: sections[clampedIndex]) {
            return work
        }
        return sections
            .filter { $0.isFinished == false }
            .compactMap(nextIncompleteWork)
            .first
    }

    private static func work(
        forSetId setId: UUID,
        in sections: [ActiveWorkoutWidgetSection]
    ) -> ActiveWorkoutWidgetWork? {
        for section in sections {
            guard let row = section.rows.first(where: { $0.id == setId }) else { continue }
            return work(from: row, in: section)
        }
        return nil
    }

    private static func nextWork(
        afterSetId setId: UUID,
        in sections: [ActiveWorkoutWidgetSection]
    ) -> ActiveWorkoutWidgetWork? {
        guard let sectionIndex = sections.firstIndex(where: { section in
            section.rows.contains { $0.id == setId }
        }), let rowIndex = sections[sectionIndex].rows.firstIndex(where: { $0.id == setId }) else {
            return currentWork(in: sections, currentExerciseIndex: 0)
        }

        let section = sections[sectionIndex]
        let followingRows = section.rows[section.rows.index(after: rowIndex)..<section.rows.endIndex]
        if let nextRow = followingRows.first(where: { $0.isCompleted == false }) {
            return work(from: nextRow, in: section)
        }

        let followingSections = sections[sections.index(after: sectionIndex)..<sections.endIndex]
        if let next = followingSections
            .filter({ $0.isFinished == false })
            .compactMap(nextIncompleteWork)
            .first {
            return next
        }

        return sections[..<sectionIndex]
            .filter { $0.isFinished == false }
            .compactMap(nextIncompleteWork)
            .first
    }

    private static func nextIncompleteWork(
        in section: ActiveWorkoutWidgetSection
    ) -> ActiveWorkoutWidgetWork? {
        guard section.isFinished == false,
              let row = section.rows.first(where: { $0.isCompleted == false }) else {
            return nil
        }
        return work(from: row, in: section)
    }

    private static func work(
        from row: ActiveSessionSetSnapshot,
        in section: ActiveWorkoutWidgetSection
    ) -> ActiveWorkoutWidgetWork {
        ActiveWorkoutWidgetWork(
            programExerciseId: section.programExercise.id,
            exerciseName: section.exerciseName,
            weightText: row.weightText.trimmingCharacters(in: .whitespacesAndNewlines),
            setNumber: row.setNumber,
            totalSets: max(section.rows.count, section.programExercise.targetSets),
            repsText: repsText(for: row, in: section)
        )
    }

    private static func repsText(
        for row: ActiveSessionSetSnapshot,
        in section: ActiveWorkoutWidgetSection
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

    private static func prescriptionText(
        for work: ActiveWorkoutWidgetWork,
        weightUnit: WeightUnit
    ) -> String {
        let setText = String(
            format: String(localized: "active_workout.set_format"),
            work.setNumber,
            work.totalSets
        )
        let weight = work.weightText.isEmpty ? nil : "\(work.weightText) \(weightUnit.localizedAbbreviation)"
        if let weight {
            return String(
                format: String(localized: "active_workout.prescription_weighted"),
                weight,
                setText,
                work.repsText
            )
        }
        return String(
            format: String(localized: "active_workout.prescription"),
            setText,
            work.repsText
        )
    }

    private static func durationText(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }

    private static func elapsedText(seconds: Int) -> String {
        guard seconds >= 60 else { return "\(seconds)s" }
        return durationText(seconds: seconds)
    }
}

private struct ActiveWorkoutWidgetSection {
    var programExercise: ProgramExercise
    var exerciseName: String
    var rows: [ActiveSessionSetSnapshot]
    var isFinished: Bool

    static func makeSections(from snapshot: ActiveSessionSnapshot) -> [ActiveWorkoutWidgetSection] {
        let rowsByProgramExerciseId = Dictionary(grouping: snapshot.rowStates) { $0.programExerciseId }
        let finishedExerciseIds = Set(snapshot.finishedExerciseIds)

        return snapshot.programExercises.map { programExercise in
            ActiveWorkoutWidgetSection(
                programExercise: programExercise,
                exerciseName: snapshot.exerciseLookup[programExercise.exerciseId]?.name
                    ?? String(localized: "workout.exercise.unknownExercise"),
                rows: (rowsByProgramExerciseId[programExercise.id] ?? []).sorted { $0.setNumber < $1.setNumber },
                isFinished: finishedExerciseIds.contains(programExercise.id)
            )
        }
    }
}

private struct ActiveWorkoutWidgetWork: Equatable {
    var programExerciseId: UUID
    var exerciseName: String
    var weightText: String
    var setNumber: Int
    var totalSets: Int
    var repsText: String
}
