import Foundation

extension WeightUnit {
    private static let poundsPerKilogram = 2.2046226218

    var localizedAbbreviation: String {
        switch self {
        case .kg:
            String(localized: "settings.weight_unit.kg")
        case .lb:
            String(localized: "settings.weight_unit.lb")
        }
    }

    func displayValue(fromKilograms kilograms: Double) -> Double {
        switch self {
        case .kg:
            kilograms
        case .lb:
            kilograms * Self.poundsPerKilogram
        }
    }

    func kilograms(fromDisplayValue value: Double) -> Double {
        switch self {
        case .kg:
            value
        case .lb:
            value / Self.poundsPerKilogram
        }
    }

    func formattedKilograms(
        _ kilograms: Double,
        fractionLength: ClosedRange<Int> = 0...1
    ) -> String {
        displayValue(fromKilograms: kilograms)
            .formatted(.number.precision(.fractionLength(fractionLength)))
    }

    func displayText(fromKilogramText text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, let kilograms = Double(trimmed) else {
            return text
        }
        return formattedKilograms(kilograms, fractionLength: 0...2)
    }

    func kilogramText(fromDisplayText text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "" }
        guard let displayValue = Double(trimmed) else { return text }
        return kilograms(fromDisplayValue: displayValue)
            .formatted(.number.precision(.fractionLength(0...2)))
    }

    func kilogramValue(fromDisplayText text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let displayValue = Double(trimmed), displayValue >= 0 else { return nil }
        return kilograms(fromDisplayValue: displayValue)
    }

    static func convertDisplayText(_ text: String, from oldUnit: WeightUnit, to newUnit: WeightUnit) -> String {
        guard oldUnit != newUnit else { return text }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              let displayValue = Double(trimmed),
              displayValue >= 0 else {
            return text
        }
        let kilograms = oldUnit.kilograms(fromDisplayValue: displayValue)
        return newUnit.formattedKilograms(kilograms, fractionLength: 0...2)
    }
}
