import Foundation

enum AppConstants {
    enum Supabase {
        // Replace with your actual values from supabase.com → Project Settings → API
        static let url = URL(string: "https://YOUR_PROJECT.supabase.co")!
        static let anonKey = "YOUR_ANON_KEY"
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
