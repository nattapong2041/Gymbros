import Foundation

struct StreakService {
    /// Returns the count of consecutive prior calendar weeks (ISO Mon–Sun) each
    /// containing ≥1 completed session, counting backward from the week before
    /// the current week. The current week is never counted and never breaks the
    /// streak. Returns 0 when the count is < 2 (callers treat 0 as "hidden").
    func streak(from sessions: [WorkoutSession], today: Date = .now) -> Int {
        let cal = Calendar(identifier: .iso8601)

        let completedDates = sessions
            .filter { $0.isComplete }
            .map { $0.startedAt }

        guard !completedDates.isEmpty else { return 0 }

        let weekKey: (Date) -> DateComponents = { date in
            cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        }

        let sessionWeeks = Set(completedDates.map { weekKey($0) })
        let currentWeek = weekKey(today)

        var count = 0
        var cursor = today
        while true {
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            let key = weekKey(prev)
            if key == currentWeek { break }
            if sessionWeeks.contains(key) {
                count += 1
                cursor = prev
            } else {
                break
            }
        }

        return count >= 2 ? count : 0
    }
}
