import AuthenticationServices
import Foundation
import Testing
@testable import Gymbros

@MainActor
@Suite("SignInViewModel")
struct SignInViewModelTests {

    private func isIdle(_ state: ViewState<Void>) -> Bool {
        if case .idle = state { return true }
        return false
    }

    private func errorValue(_ state: ViewState<Void>) -> AppError? {
        if case .error(let error) = state { return error }
        return nil
    }

    // MARK: - Google success

    @Test func google_success_setsSuccessAndRecordsLastUsed() async {
        let auth = SpyAuthService()
        let store = SpyLastUsedStore()
        let vm = SignInViewModel(
            auth: auth,
            googleCredentialProvider: StubGoogleCredentialProvider(
                result: .success(GoogleCredential(
                    idToken: "id-token",
                    accessToken: "access-token",
                    email: "lifter@gmail.com",
                    fullName: "Somchai Jaidee"
                ))
            ),
            lastUsedStore: store
        )

        await vm.signInWithGoogle()

        guard case .success = vm.state else { Issue.record("expected .success, got \(vm.state)"); return }
        #expect(vm.pendingProvider == nil)
        #expect(store.recorded == [.google])
        #expect(auth.lastCall?.provider == .google)
        #expect(auth.lastCall?.idToken == "id-token")
        #expect(auth.lastCall?.accessToken == "access-token")
        #expect(auth.lastCall?.email == "lifter@gmail.com")
        #expect(auth.lastCall?.fullName == "Somchai Jaidee")
    }

    /// The provider is handed sha256(raw); Supabase must receive the raw nonce.
    @Test func google_passesRawNonceToSupabase_notTheHashHandedToGoogle() async {
        let auth = SpyAuthService()
        let stub = StubGoogleCredentialProvider(
            result: .success(GoogleCredential(idToken: "t", accessToken: "a", email: nil, fullName: nil))
        )
        let vm = SignInViewModel(auth: auth, googleCredentialProvider: stub, lastUsedStore: SpyLastUsedStore())

        await vm.signInWithGoogle()

        let rawNonce = try! #require(auth.lastCall?.nonce)
        let hashedNonce = try! #require(stub.receivedHashedNonce)
        #expect(rawNonce != hashedNonce)
        #expect(NonceGenerator.sha256(rawNonce) == hashedNonce)
    }

    // MARK: - Google failure

    @Test func google_failure_setsErrorAndLeavesLastUsedUntouched() async {
        let store = SpyLastUsedStore()
        let vm = SignInViewModel(
            auth: SpyAuthService(),
            googleCredentialProvider: StubGoogleCredentialProvider(
                result: .failure(GoogleCredentialError.missingIDToken)
            ),
            lastUsedStore: store
        )

        await vm.signInWithGoogle()

        guard case .error = vm.state else { Issue.record("expected .error, got \(vm.state)"); return }
        #expect(vm.pendingProvider == nil)
        #expect(store.recorded.isEmpty)
    }

    @Test func google_authExchangeFailure_setsError() async {
        let auth = SpyAuthService()
        auth.errorToThrow = AppError.network(.offline)
        let vm = SignInViewModel(
            auth: auth,
            googleCredentialProvider: StubGoogleCredentialProvider(
                result: .success(GoogleCredential(idToken: "t", accessToken: "a", email: nil, fullName: nil))
            ),
            lastUsedStore: SpyLastUsedStore()
        )

        await vm.signInWithGoogle()

        #expect(errorValue(vm.state) == .network(.offline))
    }

    // MARK: - Cancellation

    @Test func google_cancellation_returnsToIdleWithoutError() async {
        let store = SpyLastUsedStore()
        let vm = SignInViewModel(
            auth: SpyAuthService(),
            googleCredentialProvider: StubGoogleCredentialProvider(result: .failure(AppError.cancelled)),
            lastUsedStore: store
        )

        await vm.signInWithGoogle()

        #expect(isIdle(vm.state))
        #expect(vm.pendingProvider == nil)
        #expect(store.recorded.isEmpty)
    }

    @Test func google_gidCanceledNSError_returnsToIdle() async {
        let canceled = NSError(domain: "com.google.GIDSignIn", code: -5)
        let vm = SignInViewModel(
            auth: SpyAuthService(),
            googleCredentialProvider: StubGoogleCredentialProvider(result: .failure(canceled)),
            lastUsedStore: SpyLastUsedStore()
        )

        await vm.signInWithGoogle()

        #expect(isIdle(vm.state))
    }

    @Test func google_nonCancellationGIDError_setsErrorNotIdle() async {
        // A GID error whose code is *not* .canceled (-5) — e.g. -4 hasNoAuthInKeychain.
        let gidFailure = NSError(domain: "com.google.GIDSignIn", code: -4)
        let vm = SignInViewModel(
            auth: SpyAuthService(),
            googleCredentialProvider: StubGoogleCredentialProvider(result: .failure(gidFailure)),
            lastUsedStore: SpyLastUsedStore()
        )

        await vm.signInWithGoogle()

        guard case .error = vm.state else { Issue.record("expected .error, got \(vm.state)"); return }
    }

    @Test func google_success_clearsLoadingAndPendingProvider() async {
        let vm = SignInViewModel(
            auth: SpyAuthService(),
            googleCredentialProvider: StubGoogleCredentialProvider(
                result: .success(GoogleCredential(idToken: "t", accessToken: "a", email: nil, fullName: nil))
            ),
            lastUsedStore: SpyLastUsedStore()
        )

        await vm.signInWithGoogle()

        guard case .success = vm.state else { Issue.record("expected .success, got \(vm.state)"); return }
        #expect(vm.pendingProvider == nil)
    }

    // MARK: - In-flight state

    @Test func google_marksGooglePendingAndLoadingWhileInFlight() async {
        let stub = StubGoogleCredentialProvider(
            result: .success(GoogleCredential(idToken: "t", accessToken: "a", email: nil, fullName: nil)),
            delay: .milliseconds(80)
        )
        let vm = SignInViewModel(auth: SpyAuthService(), googleCredentialProvider: stub, lastUsedStore: SpyLastUsedStore())

        async let run: Void = vm.signInWithGoogle()
        while stub.callCount == 0 { await Task.yield() }

        #expect(vm.pendingProvider == .google)
        if case .loading = vm.state {} else { Issue.record("expected .loading while in flight, got \(vm.state)") }

        await run
        #expect(vm.pendingProvider == nil)
    }

    // MARK: - Re-entrancy

    @Test func google_ignoresSecondCallWhilePending() async {
        let stub = StubGoogleCredentialProvider(
            result: .success(GoogleCredential(idToken: "t", accessToken: "a", email: nil, fullName: nil)),
            delay: .milliseconds(50)
        )
        let vm = SignInViewModel(auth: SpyAuthService(), googleCredentialProvider: stub, lastUsedStore: SpyLastUsedStore())

        async let first: Void = vm.signInWithGoogle()
        await Task.yield()
        await vm.signInWithGoogle() // should early-return; pendingProvider already set
        await first

        #expect(stub.callCount == 1)
    }

    // MARK: - Apple

    @Test func prepareAppleSignIn_requestsFullNameAndEmailWithHashedNonce() {
        let vm = SignInViewModel(auth: SpyAuthService(), googleCredentialProvider: noopGoogle(), lastUsedStore: SpyLastUsedStore())
        let request = ASAuthorizationAppleIDProvider().createRequest()

        vm.prepareAppleSignIn(request)

        #expect(request.requestedScopes?.contains(.fullName) == true)
        #expect(request.requestedScopes?.contains(.email) == true)
        // request.nonce is sha256(raw) — 64 lowercase hex chars, never the raw nonce.
        let nonce = try! #require(request.nonce)
        #expect(nonce.count == 64)
        #expect(nonce.allSatisfy { $0.isHexDigit && !$0.isUppercase })
        #expect(isIdle(vm.state))
    }

    @Test func handleAppleSignIn_userCancellation_returnsToIdle() async {
        let store = SpyLastUsedStore()
        let vm = SignInViewModel(auth: SpyAuthService(), googleCredentialProvider: noopGoogle(), lastUsedStore: store)
        let canceled = NSError(domain: ASAuthorizationError.errorDomain, code: ASAuthorizationError.canceled.rawValue)

        await vm.handleAppleSignIn(.failure(canceled))

        #expect(isIdle(vm.state))
        #expect(vm.pendingProvider == nil)
        #expect(store.recorded.isEmpty)
    }

    @Test func handleAppleSignIn_nonCancellationFailure_setsMappedError() async {
        let vm = SignInViewModel(auth: SpyAuthService(), googleCredentialProvider: noopGoogle(), lastUsedStore: SpyLastUsedStore())

        await vm.handleAppleSignIn(.failure(URLError(.notConnectedToInternet)))

        #expect(errorValue(vm.state) == .network(.offline))
        #expect(vm.pendingProvider == nil)
    }

    // MARK: - isUserCancellation

    @Test func isUserCancellation_recognizesAppleCanceled() {
        let appleCanceled = NSError(
            domain: "com.apple.AuthenticationServices.AuthorizationError",
            code: 1001
        )
        #expect(SignInViewModel.isUserCancellation(appleCanceled))
    }

    @Test func isUserCancellation_isFalseForGenuineErrors() {
        #expect(SignInViewModel.isUserCancellation(URLError(.timedOut)) == false)
        #expect(SignInViewModel.isUserCancellation(AppError.network(.offline)) == false)
        #expect(SignInViewModel.isUserCancellation(NSError(domain: "com.google.GIDSignIn", code: -4)) == false)
    }

    private func noopGoogle() -> StubGoogleCredentialProvider {
        StubGoogleCredentialProvider(
            result: .success(GoogleCredential(idToken: "unused", accessToken: "unused", email: nil, fullName: nil))
        )
    }
}

// MARK: - Test doubles

@MainActor
private final class SpyAuthService: AuthService {
    struct Call {
        let provider: AuthProvider
        let idToken: String
        let accessToken: String?
        let nonce: String
        let email: String?
        let fullName: String?
    }

    var lastCall: Call?
    var errorToThrow: Error?

    override func signIn(
        provider: AuthProvider,
        idToken: String,
        accessToken: String? = nil,
        nonce: String,
        email: String?,
        fullName: String?
    ) async throws {
        lastCall = Call(
            provider: provider, idToken: idToken, accessToken: accessToken,
            nonce: nonce, email: email, fullName: fullName
        )
        if let errorToThrow { throw errorToThrow }
    }
}

@MainActor
private final class StubGoogleCredentialProvider: GoogleCredentialProviding {
    private let result: Result<GoogleCredential, Error>
    private let delay: Duration?
    private(set) var receivedHashedNonce: String?
    private(set) var callCount = 0

    init(result: Result<GoogleCredential, Error>, delay: Duration? = nil) {
        self.result = result
        self.delay = delay
    }

    func signIn(hashedNonce: String) async throws -> GoogleCredential {
        callCount += 1
        receivedHashedNonce = hashedNonce
        if let delay { try? await Task.sleep(for: delay) }
        return try result.get()
    }
}

@MainActor
private final class SpyLastUsedStore: LastUsedAuthProviderStoring {
    private(set) var recorded: [AuthProvider] = []
    var lastUsed: AuthProvider? { recorded.last }
    func record(_ provider: AuthProvider) { recorded.append(provider) }
}
