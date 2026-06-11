import Foundation
import Observation

@MainActor
@Observable
final class ActiveWorkoutWidgetViewModel {
    var snapshot: ActiveSessionSnapshot?
    var isWorkoutSessionVisible = false
    private(set) var suppressedSessionId: UUID?

    private let backupRepository: ActiveSessionBackupRepositoryProviding
    private let restTimerScheduler: RestTimerScheduling
    private let liveActivityController: RestTimerLiveActivityControlling
    private let userDefaults: UserDefaults
    private let suppressedSessionKey: String

    init(
        backupRepository: ActiveSessionBackupRepositoryProviding? = nil,
        restTimerScheduler: RestTimerScheduling? = nil,
        liveActivityController: RestTimerLiveActivityControlling? = nil,
        userDefaults: UserDefaults = .standard,
        suppressedSessionKey: String = AppConstants.Storage.suppressedActiveSessionWidgetKey
    ) {
        self.backupRepository = backupRepository ?? ActiveSessionBackupRepository()
        self.restTimerScheduler = restTimerScheduler ?? RestTimerNotificationScheduler()
        self.liveActivityController = liveActivityController ?? RestTimerLiveActivityController()
        self.userDefaults = userDefaults
        self.suppressedSessionKey = suppressedSessionKey
        self.suppressedSessionId = userDefaults.string(forKey: suppressedSessionKey).flatMap(UUID.init(uuidString:))
    }

    var visibleSnapshot: ActiveSessionSnapshot? {
        guard isWorkoutSessionVisible == false,
              let snapshot,
              snapshot.session.endedAt == nil,
              snapshot.session.id != suppressedSessionId else {
            return nil
        }
        return snapshot
    }

    func refresh() {
        switch backupRepository.loadBackup() {
        case .success(let snapshot):
            self.snapshot = snapshot
            reconcileSuppression(with: snapshot)
        case .failure:
            snapshot = nil
        }
    }

    func setWorkoutSessionVisible(_ isVisible: Bool) {
        isWorkoutSessionVisible = isVisible
        if isVisible {
            clearSuppression()
        }
    }

    func stopAndSuppressCurrentSession() async {
        guard let sessionId = snapshot?.session.id else { return }
        setSuppressedSessionId(sessionId)
        restTimerScheduler.cancel(sessionId: sessionId)
        await liveActivityController.end()
    }

    func clear() {
        snapshot = nil
        isWorkoutSessionVisible = false
        clearSuppression()
    }

    private func reconcileSuppression(with snapshot: ActiveSessionSnapshot?) {
        guard let sessionId = snapshot?.session.id else {
            clearSuppression()
            return
        }
        if let suppressedSessionId, suppressedSessionId != sessionId {
            clearSuppression()
        }
    }

    private func setSuppressedSessionId(_ sessionId: UUID) {
        suppressedSessionId = sessionId
        userDefaults.set(sessionId.uuidString, forKey: suppressedSessionKey)
    }

    private func clearSuppression() {
        suppressedSessionId = nil
        userDefaults.removeObject(forKey: suppressedSessionKey)
    }
}
