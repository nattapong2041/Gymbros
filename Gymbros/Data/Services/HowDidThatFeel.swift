import Foundation

enum HowDidThatFeel: CaseIterable {
    case easy
    case justRight
    case hard

    var rpe: Double {
        switch self {
        case .easy: 6.0
        case .justRight: 7.5
        case .hard: 9.0
        }
    }

    var symbolName: String {
        switch self {
        case .easy: "face.smiling"
        case .justRight: "checkmark.circle"
        case .hard: "flame"
        }
    }

    var titleKey: String {
        switch self {
        case .easy: "workout.set.feel.easy"
        case .justRight: "workout.set.feel.just_right"
        case .hard: "workout.set.feel.hard"
        }
    }

    static func nearest(to rpe: Double) -> HowDidThatFeel {
        if rpe <= 6.75 { return .easy }
        if rpe <= 8.25 { return .justRight }
        return .hard
    }
}
