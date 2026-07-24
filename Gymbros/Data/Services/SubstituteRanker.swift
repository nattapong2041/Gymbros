import Foundation

struct SubstituteCandidate: Identifiable, Equatable {
    var id: UUID { exercise.id }
    let exercise: Exercise
    let lastLoggedWeightKg: Double?
}

enum SubstituteRanker {
    static let minimumRankedResultsBeforeBrowseAllFallback = 3

    static func filter(original: Exercise, library: [Exercise]) -> [Exercise] {
        library.filter {
            $0.id != original.id
                && $0.movementPattern == original.movementPattern
                && $0.primaryMuscle == original.primaryMuscle
        }
    }

    static func rank(
        original: Exercise,
        candidates: [Exercise],
        lastLoggedWeightsKg: [UUID: Double]
    ) -> [SubstituteCandidate] {
        candidates
            .map { SubstituteCandidate(exercise: $0, lastLoggedWeightKg: lastLoggedWeightsKg[$0.id]) }
            .sorted { lhs, rhs in
                let lhsDifferentEquipment = lhs.exercise.equipment != original.equipment
                let rhsDifferentEquipment = rhs.exercise.equipment != original.equipment
                if lhsDifferentEquipment != rhsDifferentEquipment {
                    return lhsDifferentEquipment
                }

                let lhsHasHistory = lhs.lastLoggedWeightKg != nil
                let rhsHasHistory = rhs.lastLoggedWeightKg != nil
                if lhsHasHistory != rhsHasHistory {
                    return lhsHasHistory
                }

                return lhs.exercise.name < rhs.exercise.name
            }
    }
}
