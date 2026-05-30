import Testing
import Foundation
@testable import Gymbros

@Suite("Enum Tests")
struct EnumsTests {

    @Test func goalRawValuesMatchDatabase() {
        #expect(Goal.fatLoss.rawValue == "fat_loss")
        #expect(Goal.strength.rawValue == "strength")
        #expect(Goal.muscle.rawValue == "muscle")
        #expect(Goal.general.rawValue == "general")
    }

    @Test func movementPatternRoundTripsJSON() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for pattern in MovementPattern.allCases {
            let data = try encoder.encode(pattern)
            let decoded = try decoder.decode(MovementPattern.self, from: data)
            #expect(pattern == decoded)
        }
    }

    @Test func muscleGroupRoundTripsJSON() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for muscle in MuscleGroup.allCases {
            let data = try encoder.encode(muscle)
            let decoded = try decoder.decode(MuscleGroup.self, from: data)
            #expect(muscle == decoded)
        }
    }

    @Test func equipmentRoundTripsJSON() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for equip in Equipment.allCases {
            let data = try encoder.encode(equip)
            let decoded = try decoder.decode(Equipment.self, from: data)
            #expect(equip == decoded)
        }
    }

    @Test func weightUnitRawValues() {
        #expect(WeightUnit.kg.rawValue == "kg")
        #expect(WeightUnit.lb.rawValue == "lb")
    }

    @Test func weightUnitConvertsBetweenKilogramsAndPounds() {
        #expect(WeightUnit.kg.formattedKilograms(60) == "60")
        #expect(WeightUnit.lb.formattedKilograms(60) == "132.3")
        #expect(WeightUnit.lb.kilogramValue(fromDisplayText: "132.3")! > 59.9)
        #expect(WeightUnit.lb.kilogramValue(fromDisplayText: "132.3")! < 60.1)
    }
}
