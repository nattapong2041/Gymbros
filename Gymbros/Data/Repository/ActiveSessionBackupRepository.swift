import Foundation

@MainActor
protocol ActiveSessionBackupRepositoryProviding {
    func loadBackup() -> Result<ActiveSessionSnapshot?, AppError>
    func saveBackup(_ snapshot: ActiveSessionSnapshot) -> Result<Void, AppError>
    func clearBackup()
}

@MainActor
final class ActiveSessionBackupRepository: ActiveSessionBackupRepositoryProviding {
    private let localStore: ActiveSessionBackupLocalStoring

    init(localStore: ActiveSessionBackupLocalStoring? = nil) {
        self.localStore = localStore ?? ActiveSessionBackupStore()
    }

    func loadBackup() -> Result<ActiveSessionSnapshot?, AppError> {
        localStore.load()
    }

    func saveBackup(_ snapshot: ActiveSessionSnapshot) -> Result<Void, AppError> {
        localStore.save(snapshot)
    }

    func clearBackup() {
        localStore.clear()
    }
}
