import Foundation

struct LastSessionReference: Equatable {
    enum Label: Equatable {
        case last
        case baseline
    }

    var label: Label
    var weight: Double?
    var reps: [Int]
    var unit: WeightUnit
    var isFallback: Bool
}

struct LastSessionLookupService {
    func reference(
        for programExerciseId: UUID,
        exerciseId: UUID,
        in sessions: [WorkoutSession],
        sets: [UUID: [WorkoutSet]],
        unit: WeightUnit
    ) -> LastSessionReference? {
        let completed = sessions
            .filter(\.isComplete)
            .sorted { $0.startedAt > $1.startedAt }

        if let sameProgramReference = find(
            in: completed,
            sets: sets,
            matching: { $0.programExerciseId == programExerciseId },
            unit: unit,
            isFallback: false
        ) {
            return sameProgramReference
        }

        return find(
            in: completed,
            sets: sets,
            matching: { $0.exerciseId == exerciseId },
            unit: unit,
            isFallback: true
        )
    }

    private func find(
        in sessions: [WorkoutSession],
        sets: [UUID: [WorkoutSet]],
        matching predicate: (WorkoutSet) -> Bool,
        unit: WeightUnit,
        isFallback: Bool
    ) -> LastSessionReference? {
        for session in sessions {
            let matchingSets = (sets[session.id] ?? [])
                .filter(predicate)
                .sorted { $0.setNumber < $1.setNumber }
            guard matchingSets.isEmpty == false else { continue }
            return makeReference(from: matchingSets, unit: unit, isFallback: isFallback)
        }
        return nil
    }

    private func makeReference(
        from sets: [WorkoutSet],
        unit: WeightUnit,
        isFallback: Bool
    ) -> LastSessionReference {
        let firstWeight = sets[0].weight
        return LastSessionReference(
            label: .last,
            weight: firstWeight == 0 ? nil : unit.displayValue(fromKilograms: firstWeight),
            reps: sets.map(\.reps),
            unit: unit,
            isFallback: isFallback
        )
    }
}
