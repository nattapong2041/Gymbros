import Testing
import Foundation
@testable import Gymbros

@Suite("StreakService")
struct StreakServiceTests {
    // Fixed reference: 2025-01-08 (Wednesday, ISO 2025-W02)
    // Prior weeks: W01=Dec30–Jan5, W52=Dec23–29 2024, W51=Dec16–22, etc.
    private let cal = Calendar(identifier: .iso8601)
    private let today: Date = {
        var c = DateComponents()
        c.year = 2025; c.month = 1; c.day = 8; c.hour = 12
        return Calendar(identifier: .iso8601).date(from: c)!
    }()

    private func completed(weeksAgo: Int) -> WorkoutSession {
        let start = Calendar(identifier: .iso8601)
            .date(byAdding: .day, value: -(7 * weeksAgo), to: {
                var c = DateComponents()
                c.year = 2025; c.month = 1; c.day = 8; c.hour = 12
                return Calendar(identifier: .iso8601).date(from: c)!
            }())!
        return WorkoutSession(
            id: UUID(), userId: UUID(), programDayId: nil,
            startedAt: start, endedAt: start.addingTimeInterval(3600),
            notes: nil, createdAt: start
        )
    }

    private func incomplete(weeksAgo: Int) -> WorkoutSession {
        let start = Calendar(identifier: .iso8601)
            .date(byAdding: .day, value: -(7 * weeksAgo), to: {
                var c = DateComponents()
                c.year = 2025; c.month = 1; c.day = 8; c.hour = 12
                return Calendar(identifier: .iso8601).date(from: c)!
            }())!
        return WorkoutSession(
            id: UUID(), userId: UUID(), programDayId: nil,
            startedAt: start, endedAt: nil,
            notes: nil, createdAt: start
        )
    }

    private let service = StreakService()

    @Test func zeroSessionsReturnsZero() {
        #expect(service.streak(from: [], today: today) == 0)
    }

    @Test func sessionsOnlyInCurrentWeekReturnZero() {
        // Sessions on Jan 6–7 land in W02 (current week) — not counted
        let s = completed(weeksAgo: 0) // today Jan 8, so 0 weeks ago = current week
        // Force startedAt into current week: 2 days before today
        let currentWeekDate = cal.date(byAdding: .day, value: -2, to: today)!
        let session = WorkoutSession(
            id: UUID(), userId: UUID(), programDayId: nil,
            startedAt: currentWeekDate, endedAt: currentWeekDate.addingTimeInterval(3600),
            notes: nil, createdAt: currentWeekDate
        )
        #expect(service.streak(from: [session], today: today) == 0)
    }

    @Test func onePriorWeekReturnZeroBelowThreshold() {
        // W01 only (1 consecutive prior week) → below threshold → 0
        let s = completed(weeksAgo: 1) // Jan 1, ISO 2025-W01
        #expect(service.streak(from: [s], today: today) == 0)
    }

    @Test func twoPriorConsecutiveWeeksReturnsTwo() {
        // W01 (Jan 1) + W52-2024 (Dec 25) — spans a year boundary
        let w01 = completed(weeksAgo: 1)
        let w52 = completed(weeksAgo: 2)
        #expect(service.streak(from: [w01, w52], today: today) == 2)
    }

    @Test func fivePriorConsecutiveWeeksReturnsFive() {
        let sessions = (1...5).map { completed(weeksAgo: $0) }
        #expect(service.streak(from: sessions, today: today) == 5)
    }

    @Test func gapTwoWeeksAgoReturnsZero() {
        // W01 present, W52 absent, W51 present → first gap at W52 → count=1 → 0
        let w01 = completed(weeksAgo: 1) // Jan 1 (W01-2025)
        let w51 = completed(weeksAgo: 3) // Dec 18 (W51-2024)
        #expect(service.streak(from: [w01, w51], today: today) == 0)
    }

    @Test func incompleteSessionsExcluded() {
        // W01 and W52 both have incomplete sessions → treated as if no sessions
        let w01 = incomplete(weeksAgo: 1)
        let w52 = incomplete(weeksAgo: 2)
        #expect(service.streak(from: [w01, w52], today: today) == 0)
    }

    @Test func incompleteSessionsDoNotCountTowardStreak() {
        // W01 has both complete + incomplete; W52 has only incomplete
        // → W01 has a session, W52 does not → count=1 → 0
        let w01Complete = completed(weeksAgo: 1)
        let w01Incomplete = incomplete(weeksAgo: 1)
        let w52Incomplete = incomplete(weeksAgo: 2)
        #expect(service.streak(from: [w01Complete, w01Incomplete, w52Incomplete], today: today) == 0)
    }

    @Test func yearBoundaryCountedCorrectly() {
        // today = 2025-W02; sessions in 2025-W01 (Dec 30–Jan 5) and 2024-W52 (Dec 23–29)
        // yearForWeekOfYear differs: 2025 vs 2024. Algorithm must handle this.
        let w01 = completed(weeksAgo: 1) // Jan 1, yearForWeekOfYear=2025
        let w52 = completed(weeksAgo: 2) // Dec 25, yearForWeekOfYear=2024
        #expect(service.streak(from: [w01, w52], today: today) == 2)
    }
}
