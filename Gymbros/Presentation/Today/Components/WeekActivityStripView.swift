import SwiftUI

/// Mon–Sun dots for the current week, filled on days that have a completed session.
///
/// Uses `Calendar(identifier: .iso8601)` deliberately: `StreakService` defines a week
/// the same way, so "this week" means one thing across the whole Today screen rather
/// than drifting with the device's `firstWeekday`.
struct WeekActivityStripView: View {
    let completedDates: [Date]
    var today: Date = .now

    private var calendar: Calendar { Calendar(identifier: .iso8601) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("today.week_activity.title")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(weekDays, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(
            format: String(localized: "accessibility.today.week_activity"),
            trainedCount,
            weekDays.count
        )))
    }

    private func dayCell(_ day: Date) -> some View {
        let didTrain = hasSession(on: day)
        let isToday = calendar.isDate(day, inSameDayAs: today)

        return VStack(spacing: 6) {
            Text(day.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isToday ? .primary : .secondary)

            ZStack {
                Circle()
                    // Lime = spark/progress fill, per the brand rule. Untrained days stay
                    // a neutral system fill so the trained ones are what the eye catches.
                    .fill(didTrain ? Color.brandSparkLime : Color(.tertiarySystemFill))
                    .frame(width: 28, height: 28)

                if didTrain {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        // Dark-on-lime is mandatory: lime never sits behind white text.
                        .foregroundStyle(Color.black.opacity(0.82))
                }
            }
            .overlay {
                if isToday {
                    Circle().strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var weekDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private var trainedCount: Int {
        weekDays.filter(hasSession(on:)).count
    }

    private func hasSession(on day: Date) -> Bool {
        completedDates.contains { calendar.isDate($0, inSameDayAs: day) }
    }
}

#if DEBUG
#Preview("Three trained days") {
    WeekActivityStripView(
        completedDates: [
            Date.now.addingTimeInterval(-4 * 86_400),
            Date.now.addingTimeInterval(-2 * 86_400),
            Date.now
        ]
    )
    .padding()
}

#Preview("Nothing yet") {
    WeekActivityStripView(completedDates: [])
        .padding()
}
#endif
