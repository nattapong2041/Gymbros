import Foundation
import Testing
@testable import Gymbros

@Suite("ComebackRampService")
struct ComebackRampServiceTests {
    private let service = ComebackRampService()

    @Test func exitsWhenWeightAtBaselineAndRPELow() {
        let decision = service.decide(lastComebackRPE: 7.5, currentWeight: 80, baselineWeight: 80)
        #expect(decision == .exitComeback)
    }

    @Test func exitsWhenWeightAboveBaselineAndRPELow() {
        let decision = service.decide(lastComebackRPE: 7.0, currentWeight: 82.5, baselineWeight: 80)
        #expect(decision == .exitComeback)
    }

    @Test func noExitWhenRPEHighEvenAtBaseline() {
        let decision = service.decide(lastComebackRPE: 9.0, currentWeight: 80, baselineWeight: 80)
        #expect(decision == .decrease(percent: 5))
    }

    @Test func holdsWhenNoRPEProvided() {
        let decision = service.decide(lastComebackRPE: nil, currentWeight: 70, baselineWeight: 80)
        #expect(decision == .holdAddRep)
    }

    @Test func increasesFifteenWhenRPEBelowSixPointFive() {
        let decision = service.decide(lastComebackRPE: 6.0, currentWeight: 70, baselineWeight: 80)
        #expect(decision == .increase(percent: 15))
    }

    @Test func increasesTenWhenRPEBetweenSixPointFiveAndSevenPointFive() {
        #expect(service.decide(lastComebackRPE: 6.5, currentWeight: 70, baselineWeight: 80) == .increase(percent: 10))
        #expect(service.decide(lastComebackRPE: 7.4, currentWeight: 70, baselineWeight: 80) == .increase(percent: 10))
    }

    @Test func holdsWhenRPEBetweenSevenPointFiveAndEightPointFive() {
        #expect(service.decide(lastComebackRPE: 7.5, currentWeight: 70, baselineWeight: 80) == .holdAddRep)
        #expect(service.decide(lastComebackRPE: 8.4, currentWeight: 70, baselineWeight: 80) == .holdAddRep)
    }

    @Test func decreasesFiveWhenRPEAtOrAboveEightPointFive() {
        #expect(service.decide(lastComebackRPE: 8.5, currentWeight: 70, baselineWeight: 80) == .decrease(percent: 5))
        #expect(service.decide(lastComebackRPE: 10.0, currentWeight: 70, baselineWeight: 80) == .decrease(percent: 5))
    }

    @Test func missingBaselineNeverExitsAndNeverCrashes() {
        #expect(service.decide(lastComebackRPE: nil, currentWeight: 80, baselineWeight: nil) == .holdAddRep)
        #expect(service.decide(lastComebackRPE: 7.0, currentWeight: 80, baselineWeight: nil) == .increase(percent: 10))
    }

    @Test func appliedAdjustsWeightPerDecision() {
        #expect(service.applied(.increase(percent: 10), to: 80) == 88)
        #expect(service.applied(.holdAddRep, to: 80) == 80)
        #expect(service.applied(.decrease(percent: 5), to: 80) == 76)
        #expect(service.applied(.exitComeback, to: 80) == 80)
    }
}
