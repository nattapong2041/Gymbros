import Foundation
import Testing
@testable import Gymbros

@Suite("SmartSessionAdvisor")
struct SmartSessionAdvisorTests {
    private let advisor = SmartSessionAdvisor()

    @Test(arguments: [0, 2, 6, 7, 13])
    func normalBand(days: Int) {
        let stage = advisor.stage(forDaysSinceLast: days)
        #expect(stage.isComeback == false)
        #expect(stage.weightMultiplier == 1.0)
        #expect(stage.setDelta == 0)
        #expect(stage.bandKey == "comeback.band.normal")
    }

    @Test(arguments: [14, 17, 20])
    func fourteenToTwentyBand(days: Int) {
        let stage = advisor.stage(forDaysSinceLast: days)
        #expect(stage.isComeback == true)
        #expect(stage.weightMultiplier == 0.9)
        #expect(stage.setDelta == -1)
        #expect(stage.bandKey == "comeback.band.14_20")
    }

    @Test(arguments: [21, 30, 41])
    func twentyOneToFortyOneBand(days: Int) {
        let stage = advisor.stage(forDaysSinceLast: days)
        #expect(stage.isComeback == true)
        #expect(stage.weightMultiplier == 0.8)
        #expect(stage.setDelta == -1)
        #expect(stage.bandKey == "comeback.band.21_41")
    }

    @Test(arguments: [42, 100, 365])
    func fortyTwoPlusBand(days: Int) {
        let stage = advisor.stage(forDaysSinceLast: days)
        #expect(stage.isComeback == true)
        #expect(stage.weightMultiplier == 0.6)
        #expect(stage.setDelta == -1)
        #expect(stage.bandKey == "comeback.band.42_plus")
    }

    @Test func thirteenToFourteenBoundary() {
        #expect(advisor.stage(forDaysSinceLast: 13).isComeback == false)
        #expect(advisor.stage(forDaysSinceLast: 14).isComeback == true)
    }

    @Test func fortyOneToFortyTwoBoundary() {
        #expect(advisor.stage(forDaysSinceLast: 41).weightMultiplier == 0.8)
        #expect(advisor.stage(forDaysSinceLast: 42).weightMultiplier == 0.6)
    }

    @Test func negativeDaysClampToZero() {
        let stage = advisor.stage(forDaysSinceLast: -5)
        #expect(stage.isComeback == false)
        #expect(stage.weightMultiplier == 1.0)
    }

    @Test func reasonKeyDerivesFromBandKey() {
        #expect(advisor.stage(forDaysSinceLast: 15).reasonKey == "comeback.reason.14_20")
        #expect(advisor.stage(forDaysSinceLast: 25).reasonKey == "comeback.reason.21_41")
        #expect(advisor.stage(forDaysSinceLast: 50).reasonKey == "comeback.reason.42_plus")
    }
}
