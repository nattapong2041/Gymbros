import SwiftUI

extension Color {
    /// Primary interactive — electric lime #C8FF00
    static let gymAccent = Color("AccentColor")

    /// Semantic color for text on light backgrounds that need to be readable.
    /// Uses a darker lime in light mode and electric lime in dark mode.
    static let gymAccentText = Color(uiColor: UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(named: "AccentColor") ?? .systemGreen
        } else {
            // High-contrast lime for light mode readability
            return UIColor(red: 0.47, green: 0.60, blue: 0.0, alpha: 1.0)
        }
    })

    static let gymSurface = Color(.secondarySystemBackground)
    static let gymBackground = Color(.systemBackground)
}

extension Font {
    static func gymNumber(size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}
