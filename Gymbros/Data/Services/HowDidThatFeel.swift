import Foundation

enum HowDidThatFeel: CaseIterable {
    case easy
    case moderate
    case hard
    case allOut

    /// The 1-10 RPE values this band covers, matching Apple's Workout app "Rate Your
    /// Effort" grouping (Easy/Moderate/Hard/All Out) rather than the compressed 6-9
    /// range this app used before -- lets a user pick an exact number within a band.
    var range: ClosedRange<Int> {
        switch self {
        case .easy: 1...3
        case .moderate: 4...6
        case .hard: 7...8
        case .allOut: 9...10
        }
    }

    var symbolName: String {
        switch self {
        case .easy: "face.smiling"
        case .moderate: "checkmark.circle"
        case .hard: "flame"
        case .allOut: "flame.fill"
        }
    }

    var titleKey: String {
        switch self {
        case .easy: "workout.set.feel.easy"
        case .moderate: "workout.set.feel.moderate"
        case .hard: "workout.set.feel.hard"
        case .allOut: "workout.set.feel.all_out"
        }
    }

    var descriptionKey: String {
        switch self {
        case .easy: "workout.set.feel.easy.description"
        case .moderate: "workout.set.feel.moderate.description"
        case .hard: "workout.set.feel.hard.description"
        case .allOut: "workout.set.feel.all_out.description"
        }
    }

    /// Buckets any stored RPE (including legacy 0.5-increment or 3-point-scale values)
    /// to the band it falls in, for display only -- never rewrites the stored value.
    static func band(for rpe: Double) -> HowDidThatFeel {
        if rpe <= 3.5 { return .easy }
        if rpe <= 6.5 { return .moderate }
        if rpe <= 8.5 { return .hard }
        return .allOut
    }
}
