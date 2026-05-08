import SwiftUI

extension Color {
    /// Primary interactive — electric lime #C8FF00
    static let gymAccent = Color("AccentColor")

    /// Special states — purple #9B7FE8
    static let gymPurple = Color("GymPurple")

    static let gymSurface = Color(.secondarySystemBackground)
    static let gymBackground = Color(.systemBackground)
}

extension Font {
    static func gymNumber(size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}
