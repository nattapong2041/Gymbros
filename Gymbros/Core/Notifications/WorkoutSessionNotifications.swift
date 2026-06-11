import Foundation

extension Notification.Name {
    static let activeSessionBackupDidChange = Notification.Name("Gymbros.activeSessionBackupDidChange")
    static let workoutSessionScreenVisibilityDidChange = Notification.Name("Gymbros.workoutSessionScreenVisibilityDidChange")
}

enum WorkoutSessionVisibilityNotification {
    static let isVisibleKey = "isVisible"
}
