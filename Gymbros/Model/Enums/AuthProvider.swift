import Foundation

/// The identity providers GymBros supports for sign-in.
///
/// Kept independent of `Supabase.Provider` so the Presentation layer never
/// imports the SDK. `AuthService` maps this to the SDK provider.
enum AuthProvider: String, Codable, CaseIterable, Sendable {
    case apple
    case google
}
