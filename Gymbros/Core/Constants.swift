import Foundation

enum AppConstants {
    enum Supabase {
        static let url = URL(string: Secrets.supabaseURL)!
        static let anonKey = Secrets.supabaseAnonKey
    }

    enum GoogleSignIn {
        /// OAuth **iOS** client ID from Google Cloud Console.
        /// Public identifier — it ships in the binary and the URL scheme; not a secret.
        /// Mirrored in Info.plist `GIDClientID`; its dot-reversed form is an
        /// Info.plist `CFBundleURLTypes` scheme.
        static let iosClientID = "39794716614-37objb4nnf99jrh8ombgod4gps8v6bj3.apps.googleusercontent.com"

        /// OAuth **Web application** client ID from Google Cloud Console.
        /// Passed to Google as the server client ID so the ID token audience matches
        /// what Supabase verifies. Mirrored in Info.plist `GIDServerClientID`.
        /// Must be listed FIRST (before the iOS client ID) in the Supabase
        /// dashboard "Client IDs" field.
        static let webClientID = "39794716614-6qqln4liinrna3fl6rsbujkuoa1ohdm7.apps.googleusercontent.com"

        /// True once both IDs above have been filled in. Guards the Google button
        /// so a misconfigured build fails loud in DEBUG instead of showing a
        /// broken Google sheet.
        static var isConfigured: Bool {
            iosClientID.hasPrefix("TODO_") == false && webClientID.hasPrefix("TODO_") == false
        }
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
        static let suppressedActiveSessionWidgetKey = "suppressed_active_session_widget"
    }
}
