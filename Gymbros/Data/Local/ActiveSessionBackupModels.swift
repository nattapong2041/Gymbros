import Foundation

struct ActiveSessionSnapshot: Codable, Equatable {
    static let currentVersion = 2

    var version: Int
    var session: WorkoutSession
    var day: ProgramDay
    var programExercises: [ProgramExercise]
    var exerciseLookup: [UUID: Exercise]
    var rowStates: [ActiveSessionSetSnapshot]
    var activeTimer: RestTimerState?
    var finishedExerciseIds: [UUID]
    var currentExerciseIndex: Int
    var defaultWeights: [UUID: Double]?
    var updatedAt: Date

    init(
        version: Int = ActiveSessionSnapshot.currentVersion,
        session: WorkoutSession,
        day: ProgramDay,
        programExercises: [ProgramExercise],
        exerciseLookup: [UUID: Exercise],
        rowStates: [ActiveSessionSetSnapshot],
        activeTimer: RestTimerState?,
        finishedExerciseIds: [UUID] = [],
        currentExerciseIndex: Int = 0,
        defaultWeights: [UUID: Double]? = nil,
        updatedAt: Date
    ) {
        self.version = version
        self.session = session
        self.day = day
        self.programExercises = programExercises
        self.exerciseLookup = exerciseLookup
        self.rowStates = rowStates
        self.activeTimer = activeTimer
        self.finishedExerciseIds = finishedExerciseIds
        self.currentExerciseIndex = currentExerciseIndex
        self.defaultWeights = defaultWeights
        self.updatedAt = updatedAt
    }
}

struct ActiveSessionSetSnapshot: Codable, Equatable {
    let id: UUID
    let exerciseId: UUID
    let programExerciseId: UUID?
    var setNumber: Int
    var weightText: String
    var repsText: String
    var rpe: Double?
    var targetRestSeconds: Int?
    var syncState: ActiveSessionSetSyncState
    var isCompleted: Bool
}

enum ActiveSessionSetSyncState: Codable, Equatable {
    case pending
    case uploading
    case uploaded
    case failed(AppError)

    private enum CodingKeys: String, CodingKey {
        case kind
        case error
    }

    private enum Kind: String, Codable {
        case pending
        case uploading
        case uploaded
        case failed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .pending:
            self = .pending
        case .uploading:
            self = .uploading
        case .uploaded:
            self = .uploaded
        case .failed:
            self = .failed(try container.decode(CodableAppError.self, forKey: .error).appError)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pending:
            try container.encode(Kind.pending, forKey: .kind)
        case .uploading:
            try container.encode(Kind.uploading, forKey: .kind)
        case .uploaded:
            try container.encode(Kind.uploaded, forKey: .kind)
        case .failed(let error):
            try container.encode(Kind.failed, forKey: .kind)
            try container.encode(CodableAppError(error), forKey: .error)
        }
    }
}

struct RestTimerState: Codable, Equatable {
    let sourceSetId: UUID
    let targetSeconds: Int
    let startedAt: Date
    let endsAt: Date

    var remainingSeconds: Int {
        remainingSeconds(at: Date())
    }

    var isComplete: Bool {
        remainingSeconds <= 0
    }

    func remainingSeconds(at date: Date) -> Int {
        max(0, Int(ceil(endsAt.timeIntervalSince(date))))
    }
}

private struct CodableAppError: Codable {
    let appError: AppError

    init(_ appError: AppError) {
        self.appError = appError
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case detail
        case statusCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        let detail = try container.decodeIfPresent(String.self, forKey: .detail)
        let statusCode = try container.decodeIfPresent(Int.self, forKey: .statusCode)

        switch kind {
        case "auth":
            appError = .auth(Self.authFailure(detail))
        case "api":
            appError = .api(Self.apiErrorCode(detail), statusCode: statusCode)
        case "network":
            appError = .network(Self.networkFailure(detail))
        case "decoding":
            appError = .decoding
        case "validation":
            appError = .validation(Self.validationFailure(detail))
        case "permissionDenied":
            appError = .permissionDenied
        case "notFound":
            appError = .notFound
        case "conflict":
            appError = .conflict
        case "rateLimited":
            appError = .rateLimited
        case "cancelled":
            appError = .cancelled
        case "unknown":
            appError = .unknown(debugID: detail ?? "restored-unknown")
        default:
            appError = .unknown(debugID: "restored-unknown")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch appError {
        case .auth(let failure):
            try container.encode("auth", forKey: .kind)
            try container.encode(Self.detail(failure), forKey: .detail)
        case .api(let code, let statusCode):
            try container.encode("api", forKey: .kind)
            try container.encode(Self.detail(code), forKey: .detail)
            try container.encodeIfPresent(statusCode, forKey: .statusCode)
        case .network(let failure):
            try container.encode("network", forKey: .kind)
            try container.encode(Self.detail(failure), forKey: .detail)
        case .decoding:
            try container.encode("decoding", forKey: .kind)
        case .validation(let failure):
            try container.encode("validation", forKey: .kind)
            try container.encode(Self.detail(failure), forKey: .detail)
        case .permissionDenied:
            try container.encode("permissionDenied", forKey: .kind)
        case .notFound:
            try container.encode("notFound", forKey: .kind)
        case .conflict:
            try container.encode("conflict", forKey: .kind)
        case .rateLimited:
            try container.encode("rateLimited", forKey: .kind)
        case .cancelled:
            try container.encode("cancelled", forKey: .kind)
        case .unknown(let debugID):
            try container.encode("unknown", forKey: .kind)
            try container.encode(debugID, forKey: .detail)
        }
    }

    private static func detail(_ failure: AuthFailure) -> String {
        switch failure {
        case .sessionMissing: "sessionMissing"
        case .tokenExpired: "tokenExpired"
        case .appleSignInCancelled: "appleSignInCancelled"
        case .appleCredentialMissing: "appleCredentialMissing"
        case .credentialExchangeFailed: "credentialExchangeFailed"
        }
    }

    private static func detail(_ failure: NetworkFailure) -> String {
        switch failure {
        case .offline: "offline"
        case .timeout: "timeout"
        case .temporary: "temporary"
        }
    }

    private static func detail(_ failure: ValidationFailure) -> String {
        switch failure {
        case .invalidInput: "invalidInput"
        case .missingRequiredField: "missingRequiredField"
        }
    }

    private static func detail(_ code: APIErrorCode) -> String {
        switch code {
        case .badRequest: "badRequest"
        case .unauthorized: "unauthorized"
        case .forbidden: "forbidden"
        case .notFound: "notFound"
        case .conflict: "conflict"
        case .rangeNotSatisfiable: "rangeNotSatisfiable"
        case .rateLimited: "rateLimited"
        case .server: "server"
        case .unavailable: "unavailable"
        case .timeout: "timeout"
        case .supabase(let code): "supabase:\(code)"
        case .unknown: "unknown"
        }
    }

    private static func authFailure(_ detail: String?) -> AuthFailure {
        switch detail {
        case "tokenExpired": .tokenExpired
        case "appleSignInCancelled": .appleSignInCancelled
        case "appleCredentialMissing": .appleCredentialMissing
        case "credentialExchangeFailed": .credentialExchangeFailed
        default: .sessionMissing
        }
    }

    private static func networkFailure(_ detail: String?) -> NetworkFailure {
        switch detail {
        case "offline": .offline
        case "timeout": .timeout
        default: .temporary
        }
    }

    private static func validationFailure(_ detail: String?) -> ValidationFailure {
        switch detail {
        case "missingRequiredField": .missingRequiredField
        default: .invalidInput
        }
    }

    private static func apiErrorCode(_ detail: String?) -> APIErrorCode {
        guard let detail else { return .unknown }
        switch detail {
        case "badRequest": return .badRequest
        case "unauthorized": return .unauthorized
        case "forbidden": return .forbidden
        case "notFound": return .notFound
        case "conflict": return .conflict
        case "rangeNotSatisfiable": return .rangeNotSatisfiable
        case "rateLimited": return .rateLimited
        case "server": return .server
        case "unavailable": return .unavailable
        case "timeout": return .timeout
        case "unknown": return .unknown
        default:
            if detail.hasPrefix("supabase:") {
                return .supabase(String(detail.dropFirst("supabase:".count)))
            }
            return .unknown
        }
    }
}
