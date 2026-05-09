import Foundation

enum AuthFailure: Equatable {
    case sessionMissing
    case tokenExpired
    case appleSignInCancelled
    case appleCredentialMissing
    case credentialExchangeFailed
}

enum NetworkFailure: Equatable {
    case offline
    case timeout
    case temporary
}

enum APIErrorCode: Equatable {
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case rangeNotSatisfiable
    case rateLimited
    case server
    case unavailable
    case timeout
    case supabase(String)
    case unknown
}

enum ValidationFailure: Equatable {
    case invalidInput
    case missingRequiredField
}

enum AppError: Error, Equatable {
    case auth(AuthFailure)
    case api(APIErrorCode, statusCode: Int?)
    case network(NetworkFailure)
    case decoding
    case validation(ValidationFailure)
    case permissionDenied
    case notFound
    case conflict
    case rateLimited
    case cancelled
    case unknown(debugID: String)

    var titleKey: String {
        switch self {
        case .auth(.sessionMissing):
            "error.auth.sessionMissing.title"
        case .auth(.appleCredentialMissing):
            "error.auth.appleCredentialMissing.title"
        case .network(.offline):
            "error.network.offline.title"
        case .network(.timeout):
            "error.network.timeout.title"
        case .permissionDenied:
            "error.permissionDenied.title"
        case .notFound:
            "error.notFound.title"
        case .conflict:
            "error.conflict.title"
        case .rateLimited:
            "error.rateLimited.title"
        case .decoding:
            "error.decoding.title"
        default:
            "error.unknown.title"
        }
    }

    var messageKey: String {
        switch self {
        case .auth(.sessionMissing):
            "error.auth.sessionMissing.message"
        case .auth(.appleCredentialMissing):
            "error.auth.appleCredentialMissing.message"
        case .network(.offline):
            "error.network.offline.message"
        case .network(.timeout):
            "error.network.timeout.message"
        case .permissionDenied:
            "error.permissionDenied.message"
        case .notFound:
            "error.notFound.message"
        case .conflict:
            "error.conflict.message"
        case .rateLimited:
            "error.rateLimited.message"
        case .decoding:
            "error.decoding.message"
        default:
            "error.unknown.message"
        }
    }

    var isVisibleToUser: Bool {
        self != .cancelled && self != .auth(.appleSignInCancelled)
    }
}
