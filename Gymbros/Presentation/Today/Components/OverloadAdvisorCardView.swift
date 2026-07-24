import SwiftUI

struct OverloadAdvisorCardView: View {
    let exerciseName: String
    let weightText: String
    let weightUnitAbbreviation: String
    let onTryNextTime: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("today.overload_advisor.title")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(action: onNotNow) {
                    Text("today.overload_advisor.not_now")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 48)

                Button(action: onTryNextTime) {
                    Text("today.overload_advisor.try_next_time")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 48)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(format: String(localized: "accessibility.today.overload_advisor_card"), bodyText)))
    }

    private var bodyText: String {
        String(
            format: String(localized: "today.overload_advisor.body"),
            "\(weightText) \(weightUnitAbbreviation)",
            exerciseName
        )
    }
}

#if DEBUG
#Preview("Stalled") {
    OverloadAdvisorCardView(
        exerciseName: "Bench Press",
        weightText: "60",
        weightUnitAbbreviation: "kg",
        onTryNextTime: {},
        onNotNow: {}
    )
    .padding()
}
#endif
