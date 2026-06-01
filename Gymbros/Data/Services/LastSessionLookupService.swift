import Foundation

struct LastSessionReference: Equatable {
    enum Label: Equatable {
        case last
        case baseline
    }

    struct SetSummary: Equatable {
        var weight: Double?
        var reps: Int
    }

    var label: Label
    var sets: [SetSummary]
    var unit: WeightUnit
    var isFallback: Bool

    var weight: Double? {
        sets.first?.weight
    }

    var reps: [Int] {
        sets.map(\.reps)
    }
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
        return LastSessionReference(
            label: .last,
            sets: sets.map { set in
                LastSessionReference.SetSummary(
                    weight: set.weight == 0 ? nil : unit.displayValue(fromKilograms: set.weight),
                    reps: set.reps
                )
            },
            unit: unit,
            isFallback: isFallback
        )
    }
}
