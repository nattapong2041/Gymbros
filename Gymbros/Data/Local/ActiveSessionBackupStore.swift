import Foundation

@MainActor
protocol ActiveSessionBackupStoring {
    func load() -> Result<ActiveSessionSnapshot?, AppError>
    func save(_ snapshot: ActiveSessionSnapshot) -> Result<Void, AppError>
    func clear()
}

@MainActor
final class ActiveSessionBackupStore: ActiveSessionBackupStoring {
    private let userDefaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        userDefaults: UserDefaults = .standard,
        key: String = AppConstants.Storage.activeSessionKey
    ) {
        self.userDefaults = userDefaults
        self.key = key

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load() -> Result<ActiveSessionSnapshot?, AppError> {
        guard let data = userDefaults.data(forKey: key) else {
            return .success(nil)
        }

        do {
            let snapshot = try decoder.decode(ActiveSessionSnapshot.self, from: data)
            guard snapshot.version == ActiveSessionSnapshot.currentVersion else {
                return .failure(.decoding)
            }
            return .success(snapshot)
        } catch {
            return .failure(ErrorMapper.map(error, context: .init(operation: "loadActiveSessionBackup")))
        }
    }

    func save(_ snapshot: ActiveSessionSnapshot) -> Result<Void, AppError> {
        do {
            let data = try encoder.encode(snapshot)
            userDefaults.set(data, forKey: key)
            return .success(())
        } catch {
            return .failure(ErrorMapper.map(error, context: .init(operation: "saveActiveSessionBackup")))
        }
    }

    func clear() {
        userDefaults.removeObject(forKey: key)
    }
}
