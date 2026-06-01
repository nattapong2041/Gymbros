import CoreGraphics

enum WorkoutSetTableLayout {
    static let spacing: CGFloat = 12
    static let minimumTapTarget: CGFloat = 48
    static let actionSpacing: CGFloat = 8

    struct Columns {
        var set: CGFloat
        var weight: CGFloat
        var reps: CGFloat
        var rpe: CGFloat
        var actions: CGFloat
        var showsInlineDelete: Bool
    }

    static func columns(for totalWidth: CGFloat, isReadOnly: Bool) -> Columns {
        let measuredWidth = totalWidth > 0 ? totalWidth : 360
        let usableWidth = max(0, measuredWidth - (spacing * 4))
        let showsInlineDelete = isReadOnly == false && measuredWidth >= 330
        let minimumActions = isReadOnly || showsInlineDelete == false
            ? minimumTapTarget
            : (minimumTapTarget * 2) + actionSpacing

        let actions = max(minimumActions, usableWidth * (showsInlineDelete ? 0.24 : 0.16))
        let remaining = max(0, usableWidth - actions)
        let set = max(28, remaining * 0.12)
        let afterSet = max(0, remaining - set)
        let rpe = max(minimumTapTarget, afterSet * 0.24)
        let inputs = max(0, afterSet - rpe)
        let weight = inputs / 2
        let reps = inputs / 2

        return Columns(
            set: set,
            weight: weight,
            reps: reps,
            rpe: rpe,
            actions: actions,
            showsInlineDelete: showsInlineDelete
        )
    }
}
