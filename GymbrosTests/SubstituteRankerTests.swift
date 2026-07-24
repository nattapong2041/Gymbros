import Testing
import Foundation
@testable import Gymbros

@Suite("SubstituteRanker")
struct SubstituteRankerTests {
    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func exercise(
        id: UUID = UUID(),
        name: String,
        pattern: MovementPattern = .push,
        muscle: MuscleGroup = .chest,
        equipment: Equipment = .barbell
    ) -> Exercise {
        Exercise(
            id: id,
            ownerUserId: nil,
            slug: name.lowercased().replacingOccurrences(of: " ", with: "_"),
            name: name,
            movementPattern: pattern,
            primaryMuscle: muscle,
            secondaryMuscles: [],
            equipment: equipment,
            isCompound: true,
            createdAt: baseDate
        )
    }

    // MARK: - filter

    @Test("filter excludes the original exercise by id")
    func filterExcludesOriginal() {
        let original = exercise(name: "Bench Press")
        let result = SubstituteRanker.filter(original: original, library: [original])
        #expect(result.isEmpty)
    }

    @Test("filter excludes exercises with a different movement pattern")
    func filterExcludesDifferentPattern() {
        let original = exercise(name: "Bench Press", pattern: .push)
        let other = exercise(name: "Barbell Row", pattern: .pull, muscle: .chest)
        let result = SubstituteRanker.filter(original: original, library: [other])
        #expect(result.isEmpty)
    }

    @Test("filter excludes exercises with a different primary muscle")
    func filterExcludesDifferentMuscle() {
        let original = exercise(name: "Bench Press", muscle: .chest)
        let other = exercise(name: "Overhead Press", pattern: .push, muscle: .shoulders)
        let result = SubstituteRanker.filter(original: original, library: [other])
        #expect(result.isEmpty)
    }

    @Test("filter includes exercises matching both pattern and muscle")
    func filterIncludesMatching() {
        let original = exercise(name: "Bench Press")
        let match = exercise(name: "Machine Chest Press", equipment: .machine)
        let result = SubstituteRanker.filter(original: original, library: [original, match])
        #expect(result.map(\.id) == [match.id])
    }

    @Test("filter on an empty library returns empty")
    func filterEmptyLibrary() {
        let original = exercise(name: "Bench Press")
        #expect(SubstituteRanker.filter(original: original, library: []).isEmpty)
    }

    // MARK: - rank

    @Test("rank orders different equipment ahead of same equipment")
    func rankPrefersDifferentEquipment() {
        let original = exercise(name: "Bench Press", equipment: .barbell)
        let sameEquipment = exercise(name: "Close Grip Bench Press", equipment: .barbell)
        let differentEquipment = exercise(name: "Machine Chest Press", equipment: .machine)

        let ranked = SubstituteRanker.rank(
            original: original,
            candidates: [sameEquipment, differentEquipment],
            lastLoggedWeightsKg: [:]
        )

        #expect(ranked.map(\.exercise.id) == [differentEquipment.id, sameEquipment.id])
    }

    @Test("rank prefers exercises with logged history within the same equipment tier")
    func rankPrefersHistory() {
        let original = exercise(name: "Bench Press", equipment: .barbell)
        let noHistory = exercise(name: "Machine Chest Press", equipment: .machine)
        let withHistory = exercise(name: "Cable Chest Press", equipment: .cable)

        let ranked = SubstituteRanker.rank(
            original: original,
            candidates: [noHistory, withHistory],
            lastLoggedWeightsKg: [withHistory.id: 40.0]
        )

        #expect(ranked.map(\.exercise.id) == [withHistory.id, noHistory.id])
    }

    @Test("rank falls back to alphabetical order as a stable tie-break")
    func rankAlphabeticalTieBreak() {
        let original = exercise(name: "Bench Press", equipment: .barbell)
        let zebra = exercise(name: "Zercher Press", equipment: .machine)
        let apple = exercise(name: "A-Frame Press", equipment: .machine)

        let ranked = SubstituteRanker.rank(
            original: original,
            candidates: [zebra, apple],
            lastLoggedWeightsKg: [:]
        )

        #expect(ranked.map(\.exercise.id) == [apple.id, zebra.id])
    }

    @Test("rank preserves the last logged weight on each candidate")
    func rankCarriesLastLoggedWeight() {
        let original = exercise(name: "Bench Press")
        let candidate = exercise(name: "Machine Chest Press", equipment: .machine)

        let ranked = SubstituteRanker.rank(
            original: original,
            candidates: [candidate],
            lastLoggedWeightsKg: [candidate.id: 42.5]
        )

        #expect(ranked.first?.lastLoggedWeightKg == 42.5)
    }

    @Test("rank on empty candidates returns empty")
    func rankEmptyCandidates() {
        let original = exercise(name: "Bench Press")
        #expect(SubstituteRanker.rank(original: original, candidates: [], lastLoggedWeightsKg: [:]).isEmpty)
    }
}
