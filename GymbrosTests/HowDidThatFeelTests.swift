import Testing
@testable import Gymbros

@Suite("HowDidThatFeel bucketing")
struct HowDidThatFeelTests {
    @Test func bandCoversFullOneToTenRangeWithNoGapsOrOverlaps() {
        var covered = Set<Int>()
        for feel in HowDidThatFeel.allCases {
            for value in feel.range {
                #expect(covered.contains(value) == false, "value \(value) claimed by more than one band")
                covered.insert(value)
            }
        }
        #expect(covered == Set(1...10))
    }

    @Test func bandBucketsEveryValueInItsOwnRangeBackToItself() {
        for feel in HowDidThatFeel.allCases {
            for value in feel.range {
                #expect(HowDidThatFeel.band(for: Double(value)) == feel)
            }
        }
    }

    @Test func bandBucketsLowerBoundaryToEasy() {
        #expect(HowDidThatFeel.band(for: 3.5) == .easy)
    }

    @Test func bandBucketsJustAboveLowerBoundaryToModerate() {
        #expect(HowDidThatFeel.band(for: 3.6) == .moderate)
    }

    @Test func bandBucketsMiddleBoundaryToModerate() {
        #expect(HowDidThatFeel.band(for: 6.5) == .moderate)
    }

    @Test func bandBucketsJustAboveMiddleBoundaryToHard() {
        #expect(HowDidThatFeel.band(for: 6.6) == .hard)
    }

    @Test func bandBucketsUpperBoundaryToHard() {
        #expect(HowDidThatFeel.band(for: 8.5) == .hard)
    }

    @Test func bandBucketsJustAboveUpperBoundaryToAllOut() {
        #expect(HowDidThatFeel.band(for: 8.6) == .allOut)
    }

    @Test func bandBucketsOutOfRangeValuesToTheNearestEnd() {
        #expect(HowDidThatFeel.band(for: 0.0) == .easy)
        #expect(HowDidThatFeel.band(for: 11.0) == .allOut)
    }

    @Test func bandReBucketsLegacyThreePointScaleValues() {
        // Sprint 6.1's original 3-option scale used 6.0/7.5/9.0 as its only canonical
        // points, on a compressed 6-9 "strength training" range. This redesign uses the
        // full 1-10 scale, so those same stored numbers now correctly land one tier
        // higher than they used to display -- this is intentional, not a regression:
        // 6, 7.5, and 9 genuinely sit in Moderate/Hard/All Out on a true 1-10 scale.
        #expect(HowDidThatFeel.band(for: 6.0) == .moderate)
        #expect(HowDidThatFeel.band(for: 7.5) == .hard)
        #expect(HowDidThatFeel.band(for: 9.0) == .allOut)
    }
}
