import Foundation
import Observation

@MainActor
@Observable
final class AppPreferences {
    static let shared = AppPreferences()

    var weightUnit: WeightUnit

    init(weightUnit: WeightUnit = .kg) {
        self.weightUnit = weightUnit
    }

    func apply(profile: Profile) {
        weightUnit = profile.weightUnit
    }

    func reset() {
        weightUnit = .kg
    }

    func refresh(profileRepository: ProfileRepositoryProviding? = nil) async {
        do {
            let repository = profileRepository ?? ProfileRepository()
            let profile = try await repository.fetchCurrentProfile()
            apply(profile: profile)
        } catch {
            #if DEBUG
            let appError = ErrorMapper.map(error, context: .init(operation: "refreshAppPreferences"))
            debugPrint("AppPreferences refresh failed: \(appError)")
            #endif
        }
    }
}
