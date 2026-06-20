import Foundation

enum RampDecision: Equatable {
    case increase(percent: Double)
    case holdAddRep
    case decrease(percent: Double)
    case exitComeback
}

struct ComebackRampService {
    func decide(
        lastComebackRPE: Double?,
        currentWeight: Double,
        baselineWeight: Double?
    ) -> RampDecision {
        if let baselineWeight,
           let rpe = lastComebackRPE,
           currentWeight >= baselineWeight,
           rpe <= 7.5 {
            return .exitComeback
        }
        guard let rpe = lastComebackRPE else { return .holdAddRep }
        if rpe < 6.5 { return .increase(percent: 15) }
        if rpe < 7.5 { return .increase(percent: 10) }
        if rpe < 8.5 { return .holdAddRep }
        return .decrease(percent: 5)
    }

    func applied(_ decision: RampDecision, to weight: Double) -> Double {
        switch decision {
        case .increase(let percent):
            weight * (1 + percent / 100)
        case .holdAddRep:
            weight
        case .decrease(let percent):
            weight * (1 - percent / 100)
        case .exitComeback:
            weight
        }
    }
}
