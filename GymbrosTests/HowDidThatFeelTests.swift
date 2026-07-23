import Testing
@testable import Gymbros

@Suite("HowDidThatFeel bucketing")
struct HowDidThatFeelTests {
    @Test func nearestBucketsCanonicalValues() {
        #expect(HowDidThatFeel.nearest(to: 6.0) == .easy)
        #expect(HowDidThatFeel.nearest(to: 7.5) == .justRight)
        #expect(HowDidThatFeel.nearest(to: 9.0) == .hard)
    }

    @Test func nearestBucketsLowerBoundaryToEasy() {
        #expect(HowDidThatFeel.nearest(to: 6.75) == .easy)
    }

    @Test func nearestBucketsJustAboveLowerBoundaryToJustRight() {
        #expect(HowDidThatFeel.nearest(to: 6.76) == .justRight)
    }

    @Test func nearestBucketsUpperBoundaryToJustRight() {
        #expect(HowDidThatFeel.nearest(to: 8.25) == .justRight)
    }

    @Test func nearestBucketsJustAboveUpperBoundaryToHard() {
        #expect(HowDidThatFeel.nearest(to: 8.26) == .hard)
    }

    @Test func nearestBucketsLegacyDecimalValues() {
        #expect(HowDidThatFeel.nearest(to: 6.5) == .easy)
        #expect(HowDidThatFeel.nearest(to: 8.0) == .justRight)
        #expect(HowDidThatFeel.nearest(to: 10.0) == .hard)
        #expect(HowDidThatFeel.nearest(to: 1.0) == .easy)
    }
}
