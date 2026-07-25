import SwiftUI

struct EquipmentIconView: View {
    let equipment: Equipment?
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(.quaternary)
                .frame(width: size, height: size)

            if let symbolName = equipment?.symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            } else if let equipment {
                Text(equipment.shortTitleKey)
                    .font(.system(size: size * 0.24, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            } else {
                Image(systemName: "questionmark")
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(equipment?.localizedTitleKey ?? "common.unknown")
    }
}

extension Equipment {
    var symbolName: String? {
        switch self {
        case .barbell:
            "figure.strengthtraining.traditional"
        case .dumbbell:
            "dumbbell.fill"
        case .cable, .bodyweight:
            "figure.strengthtraining.functional"
        case .machine, .kettlebell, .band:
            nil
        }
    }

    var localizedTitleKey: LocalizedStringKey {
        switch self {
        case .barbell: "equipment.barbell"
        case .dumbbell: "equipment.dumbbell"
        case .machine: "equipment.machine"
        case .cable: "equipment.cable"
        case .bodyweight: "equipment.bodyweight"
        case .kettlebell: "equipment.kettlebell"
        case .band: "equipment.band"
        }
    }

    fileprivate var shortTitleKey: LocalizedStringKey {
        switch self {
        case .barbell: "equipment.short.barbell"
        case .dumbbell: "equipment.short.dumbbell"
        case .machine: "equipment.short.machine"
        case .cable: "equipment.short.cable"
        case .bodyweight: "equipment.short.bodyweight"
        case .kettlebell: "equipment.short.kettlebell"
        case .band: "equipment.short.band"
        }
    }
}
