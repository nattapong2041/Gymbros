import Foundation

struct ProgramExerciseForm: Identifiable, Equatable {
    static let defaultTargetSets = 3
    static let defaultTargetRepsMin = 8
    static let defaultTargetRepsMax = 12
    static let defaultTargetRestSeconds = 90

    let id: UUID
    let exerciseId: UUID
    var targetSets: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var targetRestSeconds: Int
    var targetWeightText: String
    var notes: String

    init(
        id: UUID = UUID(),
        exerciseId: UUID = UUID(),
        targetSets: Int = Self.defaultTargetSets,
        targetRepsMin: Int = Self.defaultTargetRepsMin,
        targetRepsMax: Int = Self.defaultTargetRepsMax,
        targetRestSeconds: Int = Self.defaultTargetRestSeconds,
        targetWeightText: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.targetSets = targetSets
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.targetRestSeconds = targetRestSeconds
        self.targetWeightText = targetWeightText
        self.notes = notes
    }

    init(programExercise: ProgramExercise) {
        self.init(
            id: programExercise.id,
            exerciseId: programExercise.exerciseId,
            targetSets: programExercise.targetSets,
            targetRepsMin: programExercise.targetRepsMin,
            targetRepsMax: programExercise.targetRepsMax,
            targetRestSeconds: programExercise.targetRestSeconds,
            targetWeightText: programExercise.targetWeight.map(Self.formatTargetWeight) ?? "",
            notes: programExercise.notes ?? ""
        )
    }

    var targetWeight: Double? {
        let trimmed = targetWeightText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Double(trimmed)
    }

    var normalizedNotes: String? {
        ProgramFormValidation.normalizedOptionalText(notes)
    }

    func validate() -> AppError? {
        if ProgramFormValidation.validateSets(targetSets) != nil {
            return .validation(.invalidInput)
        }
        if ProgramFormValidation.validateRepRange(min: targetRepsMin, max: targetRepsMax) != nil {
            return .validation(.invalidInput)
        }
        if ProgramFormValidation.validateRestSeconds(targetRestSeconds) != nil {
            return .validation(.invalidInput)
        }
        if ProgramFormValidation.validateTargetWeight(targetWeightText) != nil {
            return .validation(.invalidInput)
        }
        return nil
    }

    private static func formatTargetWeight(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

enum ProgramFormValidation {
    static func normalizedProgramName(_ value: String) -> Result<String, AppError> {
        normalizedRequiredText(value)
    }

    static func normalizedDayName(_ value: String) -> Result<String, AppError> {
        normalizedRequiredText(value)
    }

    static func normalizedOptionalText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func validateSets(_ value: Int) -> AppError? {
        (1...10).contains(value) ? nil : .validation(.invalidInput)
    }

    static func validateRepRange(min: Int, max: Int) -> AppError? {
        guard (1...100).contains(min), (min...100).contains(max) else {
            return .validation(.invalidInput)
        }
        return nil
    }

    static func validateRestSeconds(_ value: Int) -> AppError? {
        (15...600).contains(value) ? nil : .validation(.invalidInput)
    }

    static func validateTargetWeight(_ value: String) -> AppError? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let number = Double(trimmed), number >= 0 else {
            return .validation(.invalidInput)
        }
        return nil
    }

    private static func normalizedRequiredText(_ value: String) -> Result<String, AppError> {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .failure(.validation(.missingRequiredField)) : .success(trimmed)
    }
}

enum ProgramOrderNormalizer {
    static func normalizeDays(_ days: [ProgramDay]) -> [ProgramDay] {
        normalizeDaySequence(days
            .sorted { $0.dayOrder == $1.dayOrder ? $0.createdAt < $1.createdAt : $0.dayOrder < $1.dayOrder }
        )
    }

    static func normalizeProgramExercises(_ exercises: [ProgramExercise]) -> [ProgramExercise] {
        normalizeProgramExerciseSequence(exercises
            .sorted { $0.exerciseOrder == $1.exerciseOrder ? $0.createdAt < $1.createdAt : $0.exerciseOrder < $1.exerciseOrder }
        )
    }

    static func moveDays(_ days: [ProgramDay], from sourceOffsets: IndexSet, to destinationOffset: Int) -> [ProgramDay] {
        normalizeDaySequence(move(normalizeDays(days), from: sourceOffsets, to: destinationOffset))
    }

    static func moveProgramExercises(_ exercises: [ProgramExercise], from sourceOffsets: IndexSet, to destinationOffset: Int) -> [ProgramExercise] {
        normalizeProgramExerciseSequence(move(normalizeProgramExercises(exercises), from: sourceOffsets, to: destinationOffset))
    }

    private static func normalizeDaySequence(_ days: [ProgramDay]) -> [ProgramDay] {
        days.enumerated().map { index, day in
            var normalized = day
            normalized.dayOrder = index
            return normalized
        }
    }

    private static func normalizeProgramExerciseSequence(_ exercises: [ProgramExercise]) -> [ProgramExercise] {
        exercises.enumerated().map { index, programExercise in
            var normalized = programExercise
            normalized.exerciseOrder = index
            return normalized
        }
    }

    private static func move<Element>(_ elements: [Element], from sourceOffsets: IndexSet, to destinationOffset: Int) -> [Element] {
        var result = elements
        let moving = sourceOffsets.sorted().map { result[$0] }

        for index in sourceOffsets.sorted(by: >) {
            result.remove(at: index)
        }

        let removedBeforeDestination = sourceOffsets.filter { $0 < destinationOffset }.count
        let insertionIndex = max(0, min(result.count, destinationOffset - removedBeforeDestination))
        result.insert(contentsOf: moving, at: insertionIndex)
        return result
    }
}
