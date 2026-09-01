import Foundation
import Auth
import Testing
@testable import Gymbros

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    @Test("Cancellation maps to cancelled")
    func cancellationMapsToCancelled() {
        let mapped = ErrorMapper.map(CancellationError(), context: .init(operation: "test"))

        #expect(mapped == .cancelled)
        #expect(mapped.isVisibleToUser == false)
    }

    @Test("Offline URL error maps to network offline")
    func offlineURLErrorMapsToNetworkOffline() {
        let mapped = ErrorMapper.map(URLError(.notConnectedToInternet), context: .init(operation: "test"))

        #expect(mapped == .network(.offline))
    }

    @Test("Timed out URL error maps to timeout")
    func timeoutURLErrorMapsToTimeout() {
        let mapped = ErrorMapper.map(URLError(.timedOut), context: .init(operation: "test"))

        #expect(mapped == .network(.timeout))
    }

    @Test("Decoding error maps to decoding")
    func decodingErrorMapsToDecoding() {
        let mapped = ErrorMapper.map(
            DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad data")),
            context: .init(operation: "test")
        )

        #expect(mapped == .decoding)
    }

    @Test("HTTP status maps to app error")
    func httpStatusMapsToAppError() {
        #expect(ErrorMapper.mapHTTPStatus(401) == .auth(.sessionMissing))
        #expect(ErrorMapper.mapHTTPStatus(403) == .permissionDenied)
        #expect(ErrorMapper.mapHTTPStatus(404) == .notFound)
        #expect(ErrorMapper.mapHTTPStatus(409) == .conflict)
        #expect(ErrorMapper.mapHTTPStatus(429) == .rateLimited)
    }

    @Test("Supabase Postgres codes map to app error")
    func supabasePostgresCodesMapToAppError() {
        #expect(ErrorMapper.mapSupabaseCode("42501") == .permissionDenied)
        #expect(ErrorMapper.mapSupabaseCode("23505") == .conflict)
        #expect(ErrorMapper.mapSupabaseCode("23503") == .conflict)
    }

    @Test("Supabase auth session missing maps to app auth error")
    func supabaseAuthSessionMissingMapsToAppAuthError() {
        let mapped = ErrorMapper.map(AuthError.sessionMissing, context: .init(operation: "test"))

        #expect(mapped == .auth(.sessionMissing))
    }

    @Test("Offline session refresh does not clear authenticated user")
    func offlineSessionRefreshDoesNotClearAuthenticatedUser() {
        #expect(AuthService.shouldClearCurrentUser(afterSessionLoadFailure: URLError(.notConnectedToInternet)) == false)
    }

    @Test("Missing session clears authenticated user")
    func missingSessionClearsAuthenticatedUser() {
        #expect(AuthService.shouldClearCurrentUser(afterSessionLoadFailure: AuthError.sessionMissing))
    }

    @Test("Auth failure cases expose dedicated localization keys")
    func authFailuresExposeDedicatedKeys() {
        #expect(AppError.auth(.credentialMissing).titleKey == "error.auth.credentialMissing.title")
        #expect(AppError.auth(.credentialMissing).messageKey == "error.auth.credentialMissing.message")
        #expect(AppError.auth(.credentialExchangeFailed).messageKey == "error.auth.credentialExchangeFailed.message")
    }

    @Test("Cancelled sign-in is never shown to the user")
    func cancelledSignInIsHidden() {
        #expect(AppError.auth(.signInCancelled).isVisibleToUser == false)
        #expect(AppError.cancelled.isVisibleToUser == false)
    }

    @Test("AppError exposes localization keys without raw messages")
    func appErrorExposesLocalizationKeysWithoutRawMessages() {
        let error = AppError.unknown(debugID: "secret-debug-id")

        #expect(error.titleKey == "error.unknown.title")
        #expect(error.messageKey == "error.unknown.message")
        #expect(error.titleKey.contains("secret-debug-id") == false)
        #expect(error.messageKey.contains("secret-debug-id") == false)
    }
}
