import Foundation
import Testing
@testable import Gymbros

@MainActor
@Suite("SettingsViewModel")
struct SettingsViewModelTests {

    private func successValue<T>(_ state: ViewState<T>) throws -> T {
        guard case .success(let value) = state else {
            throw AppError.unknown(debugID: "expected-success-state")
        }
        return value
    }

    private func makeProfile(weightUnit: WeightUnit = .kg, trainingPhase: TrainingPhase? = nil) -> Profile {
        Profile(
            id: UUID(),
            email: "test@example.com",
            name: "Test User",
            experienceLevel: .intermediate,
            goal: .strength,
            trainingPhase: trainingPhase,
            daysPerWeek: 3,
            weightUnit: weightUnit,
            locale: "en",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    @Test func load_success() async throws {
        let profile = makeProfile(weightUnit: .kg)
        let repo = FakeProfileRepository()
        repo.profile = profile
        let appPreferences = AppPreferences(weightUnit: .lb)
        let vm = SettingsViewModel(profileRepository: repo, authService: FakeAuthService(), appPreferences: appPreferences)

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.weightUnit == .kg)
        #expect(appPreferences.weightUnit == .kg)
        #expect(!data.appVersion.isEmpty)
    }

    @Test func load_failure() async throws {
        let repo = FakeProfileRepository()
        repo.fetchError = AppError.network(.offline)
        let vm = SettingsViewModel(profileRepository: repo, authService: FakeAuthService(), appPreferences: AppPreferences())

        await vm.load()

        guard case .error(let error) = vm.state else {
            Issue.record("Expected error state")
            return
        }
        #expect(error == .network(.offline))
    }

    @Test func updateWeightUnit_success() async throws {
        let profile = makeProfile(weightUnit: .kg)
        let repo = FakeProfileRepository()
        repo.profile = profile
        let appPreferences = AppPreferences(weightUnit: .kg)
        let vm = SettingsViewModel(profileRepository: repo, authService: FakeAuthService(), appPreferences: appPreferences)

        await vm.load()
        await vm.updateWeightUnit(.lb)

        let data = try successValue(vm.state)
        #expect(data.weightUnit == .lb)
        #expect(repo.updatedProfile?.weightUnit == .lb)
        #expect(appPreferences.weightUnit == .lb)
        #expect(vm.transientError == nil)
    }

    @Test func updateWeightUnit_failure_setsTransientErrorAndRollsBack() async throws {
        let profile = makeProfile(weightUnit: .kg)
        let repo = FakeProfileRepository()
        repo.profile = profile
        repo.updateError = AppError.network(.offline)
        let appPreferences = AppPreferences(weightUnit: .kg)
        let vm = SettingsViewModel(profileRepository: repo, authService: FakeAuthService(), appPreferences: appPreferences)

        await vm.load()
        await vm.updateWeightUnit(.lb)

        // Local state should rollback to previous state (.kg)
        let data = try successValue(vm.state)
        #expect(data.weightUnit == .kg)
        #expect(appPreferences.weightUnit == .kg)
        #expect(vm.transientError == .network(.offline))
    }

    @Test func updateWeightUnit_cancellationRollsBackWithoutAlert() async throws {
        let profile = makeProfile(weightUnit: .kg)
        let repo = FakeProfileRepository()
        repo.profile = profile
        repo.updateError = CancellationError()
        let appPreferences = AppPreferences(weightUnit: .kg)
        let vm = SettingsViewModel(profileRepository: repo, authService: FakeAuthService(), appPreferences: appPreferences)

        await vm.load()
        await vm.updateWeightUnit(.lb)

        let data = try successValue(vm.state)
        #expect(data.weightUnit == .kg)
        #expect(appPreferences.weightUnit == .kg)
        #expect(vm.transientError == nil)
    }

    @Test func updateTrainingPhase_success() async throws {
        let profile = makeProfile(trainingPhase: nil)
        let repo = FakeProfileRepository()
        repo.profile = profile
        let vm = SettingsViewModel(profileRepository: repo, authService: FakeAuthService(), appPreferences: AppPreferences())

        await vm.load()
        await vm.updateTrainingPhase(.bulk)

        let data = try successValue(vm.state)
        #expect(data.trainingPhase == .bulk)
        #expect(repo.updatedProfile?.trainingPhase == .bulk)
        #expect(vm.transientError == nil)
    }

    @Test func updateTrainingPhase_failure_setsTransientErrorAndRollsBack() async throws {
        let profile = makeProfile(trainingPhase: .bulk)
        let repo = FakeProfileRepository()
        repo.profile = profile
        repo.updateError = AppError.network(.offline)
        let vm = SettingsViewModel(profileRepository: repo, authService: FakeAuthService(), appPreferences: AppPreferences())

        await vm.load()
        await vm.updateTrainingPhase(.cut)

        let data = try successValue(vm.state)
        #expect(data.trainingPhase == .bulk)
        #expect(vm.transientError == .network(.offline))
    }

    @Test func signOut_success() async throws {
        let repo = FakeProfileRepository()
        let auth = FakeAuthService()
        let appPreferences = AppPreferences(weightUnit: .lb)
        let vm = SettingsViewModel(profileRepository: repo, authService: auth, appPreferences: appPreferences)

        await vm.signOut()

        #expect(auth.signOutCalled)
        #expect(appPreferences.weightUnit == .kg)
        #expect(vm.transientError == nil)
        #expect(!vm.isSigningOut)
    }

    @Test func signOut_failure_setsTransientError() async throws {
        let repo = FakeProfileRepository()
        let auth = FakeAuthService()
        auth.signOutError = AppError.network(.offline)
        let vm = SettingsViewModel(profileRepository: repo, authService: auth, appPreferences: AppPreferences())

        await vm.signOut()

        #expect(auth.signOutCalled)
        #expect(vm.transientError == .network(.offline))
        #expect(!vm.isSigningOut)
    }

    @Test func signOut_cancellationDoesNotSetTransientError() async throws {
        let repo = FakeProfileRepository()
        let auth = FakeAuthService()
        auth.signOutError = CancellationError()
        let vm = SettingsViewModel(profileRepository: repo, authService: auth, appPreferences: AppPreferences())

        await vm.signOut()

        #expect(auth.signOutCalled)
        #expect(vm.transientError == nil)
        #expect(!vm.isSigningOut)
    }
}

@MainActor
private final class FakeProfileRepository: ProfileRepositoryProviding {
    var profile: Profile?
    var fetchError: Error?
    var updateError: Error?
    var updatedProfile: Profile?

    func fetchCurrentProfile() async throws -> Profile {
        if let fetchError { throw fetchError }
        guard let profile else { throw AppError.notFound }
        return profile
    }

    func updateProfile(_ profile: Profile) async throws {
        if let updateError { throw updateError }
        self.updatedProfile = profile
    }
}

@MainActor
private final class FakeAuthService: AuthService {
    var signOutCalled = false
    var signOutError: Error?

    override func signOut() async throws {
        signOutCalled = true
        if let signOutError {
            throw signOutError
        }
        currentUser = nil
    }
}
