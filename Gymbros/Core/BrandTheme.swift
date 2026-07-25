import SwiftUI

// Brand identity — deliberately small.
//
// Guiding rule: **Apple provides the glass; we provide the color.**
// iOS 26's Liquid Glass belongs to the SYSTEM chrome (nav bars, tab bars, toolbars,
// floating controls). Apple's own apps put that glass over *clean, neutral content* —
// plain grouped lists and white cards. We do the same: use stock SwiftUI components
// everywhere and let the brand show through as tint + a few small accents.
//
// Where the brand actually appears:
//   1. `AccentColor` (violet #7B5CD6 light / #9B7FE8 dark) — the app-wide tint, so every
//      stock control (buttons, links, toggles, selected tabs) is already on-brand.
//   2. `BrandSparkBadge` — the lime capsule for PR / streak / active moments.
//   3. The Today header's brand wash — ONE signature screen, not a global texture.
//
// Do not add page-level gradients, custom glass rows, or bespoke card chrome to
// ordinary screens. If a stock component fits, use the stock component.

extension Color {
    static let brandSparkLime = Color("SparkLime")
    static let brandHeroViolet = Color("GymPurple")
}

extension View {
    /// The signature brand wash — **Today screen only.**
    /// Deliberately not a general-purpose background: ordinary screens keep Apple's
    /// neutral system backgrounds so the system glass chrome reads correctly.
    func brandHeroWash() -> some View {
        background(BrandHeroWash())
    }
}

private struct BrandHeroWash: View {
    @Environment(\.colorScheme) private var colorScheme

    private var limeOpacity: Double { colorScheme == .dark ? 0.26 : 0.16 }
    private var violetOpacity: Double { colorScheme == .dark ? 0.34 : 0.26 }

    var body: some View {
        ZStack {
            Color(.systemBackground)

            RadialGradient(
                colors: [Color.brandSparkLime.opacity(limeOpacity), .clear],
                center: .init(x: 0.12, y: 0.16),
                startRadius: 0,
                endRadius: 460
            )

            RadialGradient(
                colors: [Color.brandHeroViolet.opacity(violetOpacity), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 560
            )
        }
        .ignoresSafeArea()
    }
}

/// The lime "spark" badge — PR, streak, active program. Always dark text on lime.
/// This is the brand's one custom component; everything else is stock SwiftUI.
struct BrandSparkBadge: View {
    let systemImage: String
    let text: LocalizedStringKey

    var body: some View {
        Label {
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Color.black.opacity(0.82))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.brandSparkLime, in: Capsule())
    }
}
