import Foundation

struct ComebackStage: Equatable {
    let bandKey: String
    let weightMultiplier: Double
    let setDelta: Int
    let isComeback: Bool

    var reasonKey: String {
        bandKey.replacingOccurrences(of: ".band.", with: ".reason.")
    }
}

struct SmartSessionAdvisor {
    static let comebackThresholdDays = 14

    func stage(forDaysSinceLast days: Int) -> ComebackStage {
        switch max(days, 0) {
        case 0..<Self.comebackThresholdDays:
            ComebackStage(bandKey: "comeback.band.normal", weightMultiplier: 1.0, setDelta: 0, isComeback: false)
        case 14...20:
            ComebackStage(bandKey: "comeback.band.14_20", weightMultiplier: 0.9, setDelta: -1, isComeback: true)
        case 21...41:
            ComebackStage(bandKey: "comeback.band.21_41", weightMultiplier: 0.8, setDelta: -1, isComeback: true)
        default:
            ComebackStage(bandKey: "comeback.band.42_plus", weightMultiplier: 0.6, setDelta: -1, isComeback: true)
        }
    }
}
