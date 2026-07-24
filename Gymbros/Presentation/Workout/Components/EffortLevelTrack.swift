import SwiftUI
import UIKit

/// Pure position-to-value math for EffortLevelTrack, kept separate from the view so it
/// can be unit-tested without instantiating SwiftUI.
enum EffortLevelTrackMath {
    static func value(atX x: CGFloat, totalWidth: CGFloat, range: ClosedRange<Int>) -> Int {
        guard totalWidth > 0 else { return range.lowerBound }
        let segmentCount = range.count
        let segmentWidth = totalWidth / CGFloat(segmentCount)
        let clampedX = min(max(x, 0), totalWidth - 0.0001)
        let index = Int(clampedX / segmentWidth)
        return range.lowerBound + min(max(index, 0), segmentCount - 1)
    }
}

/// A horizontal 1-10 effort bar. Tap anywhere to jump to that level, or drag across it
/// to scrub -- both are the same `DragGesture(minimumDistance: 0)`, which fires on touch
/// down (acting as a tap) and continues to fire as the finger moves (acting as a drag).
struct EffortLevelTrack: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    init(value: Binding<Int>, range: ClosedRange<Int> = 1...10) {
        self._value = value
        self.range = range
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(Array(range), id: \.self) { number in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(number <= value ? color(for: number) : Color(.tertiarySystemFill))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        applyPosition(drag.location.x, totalWidth: geometry.size.width)
                    }
            )
        }
        .accessibilityElement()
        .accessibilityLabel(Text("workout.set.feel.picker.slider"))
        .accessibilityValue(Text(verbatim: "\(value)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(value + 1, range.upperBound)
            case .decrement:
                value = max(value - 1, range.lowerBound)
            @unknown default:
                break
            }
        }
    }

    private func applyPosition(_ x: CGFloat, totalWidth: CGFloat) {
        let newValue = EffortLevelTrackMath.value(atX: x, totalWidth: totalWidth, range: range)
        guard newValue != value else { return }
        value = newValue
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func color(for number: Int) -> Color {
        switch HowDidThatFeel.band(for: Double(number)) {
        case .easy: .green
        case .moderate: .yellow
        case .hard: .orange
        case .allOut: .red
        }
    }
}

#Preview {
    @Previewable @State var value = 7
    EffortLevelTrack(value: $value)
        .frame(height: 96)
        .padding()
}
