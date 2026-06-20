import SwiftUI

struct ComebackCardView: View {
    let recommendation: TodayRecommendation
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("today.comeback.welcome_back.th")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Text("today.comeback.welcome_back.en")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(reasonText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Text("today.comeback.subtitle")
                .font(.subheadline)
                .foregroundStyle(.primary)

            if let rampHintText {
                Text(rampHintText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Button(action: onStart) {
                Label("today.comeback.start", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 48)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onStart)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(String(
            format: String(localized: "accessibility.today.comeback_card"),
            reasonText
        )))
    }

    private var reasonText: String {
        String(format: NSLocalizedString(recommendation.reasonKey, comment: ""), recommendation.gapDays)
    }

    private var rampHintText: String? {
        let orderedExercises = recommendation.programDay?.exercises
            .sorted { $0.exerciseOrder < $1.exerciseOrder } ?? []
        let decision = orderedExercises.compactMap { recommendation.rampPreview[$0.id] }.first
            ?? recommendation.rampPreview.values.first

        switch decision {
        case .increase(let percent):
            return String(format: String(localized: "today.comeback.ramp.increase"), Int(percent))
        case .holdAddRep:
            return String(localized: "today.comeback.ramp.hold")
        case .decrease(let percent):
            return String(format: String(localized: "today.comeback.ramp.decrease"), Int(percent))
        case .exitComeback, .none:
            return nil
        }
    }
}

#if DEBUG
#Preview("First comeback session") {
    ComebackCardView(
        recommendation: TodayRecommendation(
            mode: .comeback(stage: SmartSessionAdvisor().stage(forDaysSinceLast: 15), adjustments: [:]),
            programDay: nil,
            reasonKey: "comeback.reason.14_20",
            gapDays: 15
        ),
        onStart: {}
    )
    .padding()
}

#Preview("Ramping back") {
    ComebackCardView(
        recommendation: TodayRecommendation(
            mode: .comeback(stage: SmartSessionAdvisor().stage(forDaysSinceLast: 25), adjustments: [:]),
            programDay: nil,
            reasonKey: "comeback.reason.21_41",
            gapDays: 25,
            rampPreview: [UUID(): .increase(percent: 10)]
        ),
        onStart: {}
    )
    .padding()
}
#endif
