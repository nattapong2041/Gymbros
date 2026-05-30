import Foundation
import Observation

struct SettingsData: Equatable {
    var weightUnit: WeightUnit
    let appVersion: String
}

@MainActor
@Observable
final class SettingsViewModel {
    var state: ViewState<SettingsData> = .idle
    var transientError: AppError?
    var isSigningOut: Bool = false

    private let profileRepository: ProfileRepositoryProviding
    private let authService: AuthService
    private let appPreferences: AppPreferences
    private var profile: Profile?

    init(
        profileRepository: ProfileRepositoryProviding? = nil,
        authService: AuthService? = nil,
        appPreferences: AppPreferences? = nil
    ) {
        self.profileRepository = profileRepository ?? ProfileRepository()
        self.authService = authService ?? AuthService.shared
        self.appPreferences = appPreferences ?? .shared
    }

    func load() async {
        state = .loading
        await fetch()
    }

    private func fetch() async {
        do {
            let fetchedProfile = try await profileRepository.fetchCurrentProfile()
            self.profile = fetchedProfile
            appPreferences.apply(profile: fetchedProfile)

            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            let appVersionString = "\(version) (\(build))"

            state = .success(SettingsData(
                weightUnit: fetchedProfile.weightUnit,
                appVersion: appVersionString
            ))
        } catch {
            let appError = ErrorMapper.map(error, context: .init(operation: "loadSettings"))
            if appError != .cancelled {
                state = .error(appError)
            }
        }
    }

    func updateWeightUnit(_ unit: WeightUnit) async {
        guard var updatedProfile = profile else { return }
        updatedProfile.weightUnit = unit

        let previousState = state
        if case .success(var data) = state {
            data.weightUnit = unit
            state = .success(data)
        }
        appPreferences.weightUnit = unit

        do {
            try await profileRepository.updateProfile(updatedProfile)
            self.profile = updatedProfile
        } catch {
            if let oldProfile = profile {
                appPreferences.apply(profile: oldProfile)
            }
            state = previousState
            let appError = ErrorMapper.map(error, context: .init(operation: "updateWeightUnit"))
            if appError != .cancelled {
                transientError = appError
            }
        }
    }

    func signOut() async {
        guard isSigningOut == false else { return }
        isSigningOut = true
        defer { isSigningOut = false }

        do {
            try await authService.signOut()
            appPreferences.reset()
        } catch {
            let appError = ErrorMapper.map(error, context: .init(operation: "signOut"))
            if appError != .cancelled {
                transientError = appError
            }
        }
    }
}

#if DEBUG
extension SettingsViewModel {
    static var loading: SettingsViewModel {
        preview(.loading)
    }

    static var error: SettingsViewModel {
        preview(.error(.network(.offline)))
    }

    static func success(weightUnit: WeightUnit) -> SettingsViewModel {
        preview(.success(SettingsData(weightUnit: weightUnit, appVersion: "1.0.0 (42)")))
    }

    private static func preview(_ state: ViewState<SettingsData>) -> SettingsViewModel {
        let vm = SettingsViewModel(
            profileRepository: FakeProfileRepository(),
            authService: AuthService(),
            appPreferences: AppPreferences()
        )
        vm.state = state
        return vm
    }
}

private final class FakeProfileRepository: ProfileRepositoryProviding {
    func fetchCurrentProfile() async throws -> Profile {
        Profile(
            id: UUID(),
            email: "test@example.com",
            name: "Test User",
            experienceLevel: .intermediate,
            goal: .strength,
            daysPerWeek: 3,
            weightUnit: .kg,
            locale: "en",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    func updateProfile(_ profile: Profile) async throws {}
}
#endif
