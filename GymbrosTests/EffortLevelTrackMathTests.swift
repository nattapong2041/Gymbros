import Testing
@testable import Gymbros

@Suite("EffortLevelTrackMath")
struct EffortLevelTrackMathTests {
    private let range = 1...10

    @Test func leadingEdgeMapsToLowerBound() {
        #expect(EffortLevelTrackMath.value(atX: 0, totalWidth: 300, range: range) == 1)
    }

    @Test func trailingEdgeMapsToUpperBound() {
        #expect(EffortLevelTrackMath.value(atX: 299.9, totalWidth: 300, range: range) == 10)
    }

    @Test func midpointOfEachSegmentMapsToThatSegmentsValue() {
        let segmentWidth: Double = 300 / 10
        for offset in 0..<10 {
            let x = Double(offset) * segmentWidth + segmentWidth / 2
            #expect(EffortLevelTrackMath.value(atX: x, totalWidth: 300, range: range) == 1 + offset)
        }
    }

    @Test func negativeXClampsToLowerBound() {
        #expect(EffortLevelTrackMath.value(atX: -50, totalWidth: 300, range: range) == 1)
    }

    @Test func xBeyondWidthClampsToUpperBound() {
        #expect(EffortLevelTrackMath.value(atX: 1000, totalWidth: 300, range: range) == 10)
    }

    @Test func zeroWidthReturnsLowerBoundWithoutCrashing() {
        #expect(EffortLevelTrackMath.value(atX: 50, totalWidth: 0, range: range) == 1)
    }

    @Test func respectsNonDefaultRange() {
        let narrowRange = 4...6
        #expect(EffortLevelTrackMath.value(atX: 0, totalWidth: 90, range: narrowRange) == 4)
        #expect(EffortLevelTrackMath.value(atX: 45, totalWidth: 90, range: narrowRange) == 5)
        #expect(EffortLevelTrackMath.value(atX: 89, totalWidth: 90, range: narrowRange) == 6)
    }
}
