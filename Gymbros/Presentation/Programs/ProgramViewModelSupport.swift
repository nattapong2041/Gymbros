import Foundation

enum ProgramViewModelSupport {
    static func appError(_ error: Error, operation: String) -> AppError {
        ErrorMapper.map(error, context: .init(operation: operation))
    }

    static func sortedPrograms(_ programs: [Program]) -> [Program] {
        programs.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    static func exerciseLookup(from exercises: [Exercise]) -> [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    static func matchesSearch(_ exercise: Exercise, searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return true }
        return exercise.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
