import Foundation
import Testing
@testable import Gymbros

@Suite("Program Builder Validation")
struct ProgramBuilderValidationTests {
    @Test func exerciseFormUsesSprintDefaults() {
        let form = ProgramExerciseForm()

        #expect(form.targetSets == 3)
        #expect(form.targetRepsMin == 8)
        #expect(form.targetRepsMax == 12)
        #expect(form.targetRestSeconds == 90)
        #expect(form.targetWeightText.isEmpty)
        #expect(form.targetWeight == nil)
        #expect(form.notes.isEmpty)
        #expect(form.validate() == nil)
    }

    @Test func requiredNamesTrimWhitespace() throws {
        let programName = try ProgramFormValidation.normalizedProgramName("  Upper Lower  ").get()
        let dayName = try ProgramFormValidation.normalizedDayName("\nUpper A\t").get()

        #expect(programName == "Upper Lower")
        #expect(dayName == "Upper A")
        #expect(ProgramFormValidation.normalizedProgramName("   ") == .failure(.validation(.missingRequiredField)))
        #expect(ProgramFormValidation.normalizedDayName("\n") == .failure(.validation(.missingRequiredField)))
    }

    @Test func exerciseFormValidatesPrescriptionBounds() {
        #expect(ProgramExerciseForm(targetSets: 0).validate() == .validation(.invalidInput))
        #expect(ProgramExerciseForm(targetSets: 11).validate() == .validation(.invalidInput))
        #expect(ProgramExerciseForm(targetRepsMin: 0).validate() == .validation(.invalidInput))
        #expect(ProgramExerciseForm(targetRepsMin: 13, targetRepsMax: 12).validate() == .validation(.invalidInput))
        #expect(ProgramExerciseForm(targetRepsMax: 101).validate() == .validation(.invalidInput))
        #expect(ProgramExerciseForm(targetRestSeconds: 14).validate() == .validation(.invalidInput))
        #expect(ProgramExerciseForm(targetRestSeconds: 601).validate() == .validation(.invalidInput))
    }

    @Test func targetWeightIsOptionalAndValidatesNumericBounds() {
        #expect(ProgramExerciseForm(targetWeightText: "").validate() == nil)
        #expect(ProgramExerciseForm(targetWeightText: "  ").targetWeight == nil)
        #expect(ProgramExerciseForm(targetWeightText: "72.5").targetWeight == 72.5)
        #expect(ProgramExerciseForm(targetWeightText: "72.5").validate() == nil)
        #expect(ProgramExerciseForm(targetWeightText: "-1").validate() == .validation(.invalidInput))
        #expect(ProgramExerciseForm(targetWeightText: "heavy").validate() == .validation(.invalidInput))
    }

    @Test func notesNormalizeToNilWhenBlank() {
        #expect(ProgramExerciseForm(notes: "  keep elbows tucked  ").normalizedNotes == "keep elbows tucked")
        #expect(ProgramExerciseForm(notes: " \n\t ").normalizedNotes == nil)
    }

    @Test func dayOrderNormalizationIsZeroBasedAndDense() {
        let unordered = [
            makeDay(id: "33333333-3333-3333-3333-333333333333", order: 10),
            makeDay(id: "11111111-1111-1111-1111-111111111111", order: 4),
            makeDay(id: "22222222-2222-2222-2222-222222222222", order: 4)
        ]

        let normalized = ProgramOrderNormalizer.normalizeDays(unordered)

        #expect(normalized.map(\.dayOrder) == [0, 1, 2])
        #expect(normalized.map(\.id.uuidString) == [
            "11111111-1111-1111-1111-111111111111",
            "22222222-2222-2222-2222-222222222222",
            "33333333-3333-3333-3333-333333333333"
        ])
    }

    @Test func exerciseOrderNormalizationIsZeroBasedAndDense() {
        let unordered = [
            makeProgramExercise(id: "33333333-3333-3333-3333-333333333333", order: 20),
            makeProgramExercise(id: "11111111-1111-1111-1111-111111111111", order: 2),
            makeProgramExercise(id: "22222222-2222-2222-2222-222222222222", order: 2)
        ]

        let normalized = ProgramOrderNormalizer.normalizeProgramExercises(unordered)

        #expect(normalized.map(\.exerciseOrder) == [0, 1, 2])
        #expect(normalized.map(\.id.uuidString) == [
            "11111111-1111-1111-1111-111111111111",
            "22222222-2222-2222-2222-222222222222",
            "33333333-3333-3333-3333-333333333333"
        ])
    }

    @Test func movingDaysNormalizesFinalOrder() {
        let days = [
            makeDay(id: "11111111-1111-1111-1111-111111111111", order: 0),
            makeDay(id: "22222222-2222-2222-2222-222222222222", order: 1),
            makeDay(id: "33333333-3333-3333-3333-333333333333", order: 2)
        ]

        let moved = ProgramOrderNormalizer.moveDays(days, from: IndexSet(integer: 0), to: 3)

        #expect(moved.map(\.id.uuidString) == [
            "22222222-2222-2222-2222-222222222222",
            "33333333-3333-3333-3333-333333333333",
            "11111111-1111-1111-1111-111111111111"
        ])
        #expect(moved.map(\.dayOrder) == [0, 1, 2])
    }

    @Test func movingProgramExercisesNormalizesFinalOrder() {
        let exercises = [
            makeProgramExercise(id: "11111111-1111-1111-1111-111111111111", order: 0),
            makeProgramExercise(id: "22222222-2222-2222-2222-222222222222", order: 1),
            makeProgramExercise(id: "33333333-3333-3333-3333-333333333333", order: 2)
        ]

        let moved = ProgramOrderNormalizer.moveProgramExercises(exercises, from: IndexSet(integer: 2), to: 0)

        #expect(moved.map(\.id.uuidString) == [
            "33333333-3333-3333-3333-333333333333",
            "11111111-1111-1111-1111-111111111111",
            "22222222-2222-2222-2222-222222222222"
        ])
        #expect(moved.map(\.exerciseOrder) == [0, 1, 2])
    }

    private func makeDay(id: String, order: Int) -> ProgramDay {
        ProgramDay(
            id: UUID(uuidString: id)!,
            programId: ProgramSamples.programId,
            name: "Day \(order)",
            dayOrder: order,
            createdAt: ProgramSamples.createdAt.addingTimeInterval(TimeInterval(order))
        )
    }

    private func makeProgramExercise(id: String, order: Int) -> ProgramExercise {
        ProgramExercise(
            id: UUID(uuidString: id)!,
            programDayId: ProgramSamples.upperDayId,
            exerciseId: ProgramSamples.benchExerciseId,
            targetSets: 3,
            targetRepsMin: 8,
            targetRepsMax: 12,
            targetRestSeconds: 90,
            targetWeight: nil,
            exerciseOrder: order,
            notes: nil,
            createdAt: ProgramSamples.createdAt.addingTimeInterval(TimeInterval(order))
        )
    }
}
