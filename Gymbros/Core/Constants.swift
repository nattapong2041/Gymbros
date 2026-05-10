import Foundation

enum AppConstants {
    enum Supabase {
        static let url = URL(string: Secrets.supabaseURL)!
        static let anonKey = Secrets.supabaseAnonKey
    }

    enum Workout {
        static let smallestPlateKg: Double = 2.5
        static let smallestPlateLb: Double = 5.0
        static let defaultRestSeconds = 90
        static let minRPE: Double = 1.0
        static let maxRPE: Double = 10.0
    }

    enum Storage {
        static let activeSessionKey = "active_session_backup"
    }
}
