import Foundation
import Testing
@testable import Gymbros

@Suite("Program Repository Payloads")
struct ProgramRepositoryPayloadTests {
    @Test func programInsertPayloadUsesSnakeCaseAndOmitsServerFields() throws {
        let payload = ProgramInsertPayload(
            userId: ProgramSamples.userId,
            name: "Upper/Lower",
            description: "Four days"
        )

        let dictionary = try encodeDictionary(payload)

        #expect(dictionary["user_id"] as? String == ProgramSamples.userId.uuidString.uppercased())
        #expect(dictionary["name"] as? String == "Upper/Lower")
        #expect(dictionary["description"] as? String == "Four days")
        #expect(dictionary["id"] == nil)
        #expect(dictionary["created_at"] == nil)
        #expect(dictionary["updated_at"] == nil)
        #expect(dictionary["is_active"] == nil)
    }

    @Test func programUpdatePayloadEncodesNilDescriptionToClearValue() throws {
        let payload = ProgramUpdatePayload(name: "Upper/Lower", description: nil)

        let dictionary = try encodeDictionary(payload)

        #expect(dictionary["name"] as? String == "Upper/Lower")
        #expect(dictionary["description"] is NSNull)
        #expect(dictionary["user_id"] == nil)
        #expect(dictionary["created_at"] == nil)
        #expect(dictionary["updated_at"] == nil)
    }

    @Test func dayPayloadsUseSnakeCaseAndOmitServerFields() throws {
        let insert = ProgramDayInsertPayload(
            programId: ProgramSamples.programId,
            name: "Upper A",
            dayOrder: 0
        )
        let update = ProgramDayUpdatePayload(name: "Upper B", dayOrder: 1)

        let insertDictionary = try encodeDictionary(insert)
        let updateDictionary = try encodeDictionary(update)

        #expect(insertDictionary["program_id"] as? String == ProgramSamples.programId.uuidString.uppercased())
        #expect(insertDictionary["name"] as? String == "Upper A")
        #expect(insertDictionary["day_order"] as? Int == 0)
        #expect(insertDictionary["id"] == nil)
        #expect(insertDictionary["created_at"] == nil)
        #expect(updateDictionary["name"] as? String == "Upper B")
        #expect(updateDictionary["day_order"] as? Int == 1)
        #expect(updateDictionary["program_id"] == nil)
    }

    @Test func programExercisePayloadsUseSnakeCaseAndClearNilNotes() throws {
        let insert = ProgramExerciseInsertPayload(
            programDayId: ProgramSamples.upperDayId,
            exerciseId: ProgramSamples.benchExerciseId,
            targetSets: 4,
            targetRepsMin: 6,
            targetRepsMax: 8,
            targetRestSeconds: 120,
            targetWeight: 72.5,
            exerciseOrder: 2,
            notes: "Controlled reps"
        )
        var programExercise = ProgramSamples.benchProgramExercise
        programExercise.notes = nil
        programExercise.targetWeight = nil
        let update = ProgramExerciseUpdatePayload(programExercise: programExercise)

        let insertDictionary = try encodeDictionary(insert)
        let updateDictionary = try encodeDictionary(update)

        #expect(insertDictionary["program_day_id"] as? String == ProgramSamples.upperDayId.uuidString.uppercased())
        #expect(insertDictionary["exercise_id"] as? String == ProgramSamples.benchExerciseId.uuidString.uppercased())
        #expect(insertDictionary["target_sets"] as? Int == 4)
        #expect(insertDictionary["target_reps_min"] as? Int == 6)
        #expect(insertDictionary["target_reps_max"] as? Int == 8)
        #expect(insertDictionary["target_rest_seconds"] as? Int == 120)
        #expect(insertDictionary["target_weight"] as? Double == 72.5)
        #expect(insertDictionary["exercise_order"] as? Int == 2)
        #expect(insertDictionary["notes"] as? String == "Controlled reps")
        #expect(insertDictionary["id"] == nil)
        #expect(insertDictionary["created_at"] == nil)

        #expect(updateDictionary["notes"] is NSNull)
        #expect(updateDictionary["target_weight"] is NSNull)
        #expect(updateDictionary["target_sets"] as? Int == ProgramSamples.benchProgramExercise.targetSets)
        #expect(updateDictionary["program_day_id"] == nil)
        #expect(updateDictionary["exercise_id"] == nil)
        #expect(updateDictionary["created_at"] == nil)
    }

    @MainActor
    @Test func attachDaysHydratesProgramListCounts() {
        let unrelatedProgram = Program(
            id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            userId: ProgramSamples.userId,
            name: "Empty Program",
            description: nil,
            isActive: false,
            createdAt: ProgramSamples.createdAt,
            updatedAt: ProgramSamples.createdAt
        )

        let programs = ProgramRepository.attachDays(
            ProgramSamples.days,
            to: [ProgramSamples.program, unrelatedProgram]
        )

        #expect(programs[0].days.map(\.name) == ["Upper A", "Lower A"])
        #expect(programs[0].days.map(\.dayOrder) == [0, 1])
        #expect(programs[1].days.isEmpty)
    }

    private func encodeDictionary<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
