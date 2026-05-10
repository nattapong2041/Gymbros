import Foundation
import Auth
import PostgREST

struct ErrorContext: Equatable {
    let operation: String
    let table: String?
    let statusCode: Int?
    let supabaseCode: String?

    init(
        operation: String,
        table: String? = nil,
        statusCode: Int? = nil,
        supabaseCode: String? = nil
    ) {
        self.operation = operation
        self.table = table
        self.statusCode = statusCode
        self.supabaseCode = supabaseCode
    }
}

enum ErrorMapper {
    static func map(_ error: Error, context: ErrorContext) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        if error is CancellationError {
            return .cancelled
        }

        if let postgrestError = error as? PostgrestError {
            let code = postgrestError.code
            let statusCode = context.statusCode ?? (code == "PGRST116" ? 404 : 500)
            return mapHTTPStatus(statusCode, code: code)
        }

        if let authError = error as? AuthError {
            return map(authError, context: context)
        }

        if let urlError = error as? URLError {
            return map(urlError)
        }

        if error is DecodingError || error is EncodingError {
            return .decoding
        }

        if let statusCode = context.statusCode {
            return mapHTTPStatus(statusCode, code: context.supabaseCode)
        }

        if let supabaseCode = context.supabaseCode {
            return mapSupabaseCode(supabaseCode, statusCode: nil)
        }

        return .unknown(debugID: makeDebugID(context: context))
    }

    static func mapHTTPStatus(_ statusCode: Int, code: String? = nil) -> AppError {
        if let code {
            let mapped = mapSupabaseCode(code, statusCode: statusCode)
            if mapped != .api(.supabase(code), statusCode: statusCode) {
                return mapped
            }
        }

        switch statusCode {
        case 401:
            return .auth(.sessionMissing)
        case 403:
            return .permissionDenied
        case 404:
            return .notFound
        case 409:
            return .conflict
        case 416:
            return .api(.rangeNotSatisfiable, statusCode: statusCode)
        case 429:
            return .rateLimited
        case 500:
            return .api(.server, statusCode: statusCode)
        case 503:
            return .network(.temporary)
        case 504:
            return .network(.timeout)
        default:
            return .api(apiCode(for: statusCode), statusCode: statusCode)
        }
    }

    static func mapSupabaseCode(_ code: String, statusCode: Int? = nil) -> AppError {
        switch code {
        case "42501":
            return .permissionDenied
        case "23505", "23503":
            return .conflict
        default:
            if code.hasPrefix("PGRST") {
                switch statusCode {
                case 401:
                    return .auth(.sessionMissing)
                case 403:
                    return .permissionDenied
                case 404:
                    return .notFound
                case 409:
                    return .conflict
                default:
                    return .api(.supabase(code), statusCode: statusCode)
                }
            }
            return .api(.supabase(code), statusCode: statusCode)
        }
    }

    private static func map(_ error: URLError) -> AppError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
            return .network(.offline)
        case .timedOut:
            return .network(.timeout)
        case .cancelled:
            return .cancelled
        default:
            return .network(.temporary)
        }
    }

    private static func map(_ error: AuthError, context: ErrorContext) -> AppError {
        switch error {
        case .sessionMissing:
            return .auth(.sessionMissing)
        case .jwtVerificationFailed:
            return .auth(.tokenExpired)
        case .api(_, _, _, let response):
            return mapHTTPStatus(response.statusCode)
        case .pkceGrantCodeExchange:
            return .auth(.credentialExchangeFailed)
        default:
            return .unknown(debugID: makeDebugID(context: context))
        }
    }

    private static func apiCode(for statusCode: Int) -> APIErrorCode {
        switch statusCode {
        case 400:
            .badRequest
        case 401:
            .unauthorized
        case 403:
            .forbidden
        case 404:
            .notFound
        case 409:
            .conflict
        case 416:
            .rangeNotSatisfiable
        case 429:
            .rateLimited
        case 500:
            .server
        case 503:
            .unavailable
        case 504:
            .timeout
        default:
            .unknown
        }
    }

    private static func makeDebugID(context: ErrorContext) -> String {
        let suffix = UUID().uuidString.prefix(8)
        return "\(context.operation)-\(suffix)"
    }
}
