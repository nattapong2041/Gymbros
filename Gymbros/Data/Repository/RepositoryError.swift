import Foundation

enum RepositoryError: LocalizedError {
    case notAuthenticated
    case notFound
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "User is not authenticated"
        case .notFound: "Resource not found"
        case .networkError(let error): "Network error: \(error.localizedDescription)"
        }
    }
}
