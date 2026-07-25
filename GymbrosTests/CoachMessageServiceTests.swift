import Testing
import Foundation
@testable import Gymbros

@Suite("CoachMessageService")
struct CoachMessageServiceTests {
    private let service = CoachMessageService()
    private let calendar = Calendar(identifier: .iso8601)

    /// A Wednesday, so "this week" has days on both sides of it and the week-boundary
    /// tests aren't accidentally sitting on a Monday or Sunday.
    private var now: Date {
        DateComponents(
            calendar: Calendar(identifier: .iso8601),
            timeZone: TimeZone(identifier: "UTC"),
            year: 2026, month: 7, day: 22, hour: 18
        ).date!
    }

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now)!
    }

    // MARK: - Priority order

    @Test("A session logged today wins over every other state")
    func trainedTodayTakesPriority() {
        let state = service.resolve(
            .init(
                completedSessionDates: [now],
                streakWeeks: 12,
                isWelcomeBack: true,
                isComeback: true,
                hasStalledExercise: true
            ),
            now: now
        )
        #expect(state == .trainedToday)
    }

    @Test("Comeback outranks a stall, so a returning user is never pushed to add weight")
    func comebackOutranksPlateau() {
        let state = service.resolve(
            .init(completedSessionDates: [daysAgo(20)], isComeback: true, hasStalledExercise: true),
            now: now
        )
        #expect(state == .comeback)
    }

    @Test("Being away outranks a stall for the same reason")
    func awayOutranksPlateau() {
        let state = service.resolve(
            .init(completedSessionDates: [daysAgo(9)], isWelcomeBack: true, hasStalledExercise: true),
            now: now
        )
        #expect(state == .away)
    }

    @Test("A stall outranks streak and momentum -- it's the actionable one")
    func plateauOutranksStreak() {
        let state = service.resolve(
            .init(completedSessionDates: [daysAgo(3)], streakWeeks: 6, hasStalledExercise: true),
            now: now
        )
        #expect(state == .plateau)
    }

    @Test("Falls through to ready when there is nothing to say")
    func fallsThroughToReady() {
        #expect(service.resolve(.init(), now: now) == .ready)
    }

    // MARK: - Week and day arithmetic

    @Test("Two distinct days trained this week is a roll")
    func twoDaysThisWeekIsOnARoll() {
        let state = service.resolve(
            .init(completedSessionDates: [daysAgo(1), daysAgo(2)]),
            now: now
        )
        #expect(state == .onARoll)
    }

    @Test("Two sessions on the SAME day is one day of work, not a roll")
    func sameDayTwiceDoesNotCountAsTwo() {
        let yesterday = daysAgo(1)
        let alsoYesterday = calendar.date(byAdding: .hour, value: 6, to: yesterday)!
        let state = service.resolve(
            .init(completedSessionDates: [yesterday, alsoYesterday]),
            now: now
        )
        #expect(state == .trainedYesterday)
    }

    @Test("Sessions from last week do not count toward this week")
    func lastWeekDoesNotCountTowardThisWeek() {
        let state = service.resolve(
            .init(completedSessionDates: [daysAgo(8), daysAgo(9)]),
            now: now
        )
        #expect(state != .onARoll)
    }

    @Test("Streak needs two weeks; one week is not a streak")
    func oneWeekIsNotAStreak() {
        #expect(service.resolve(.init(streakWeeks: 1), now: now) != .streak)
        #expect(service.resolve(.init(streakWeeks: 2), now: now) == .streak)
    }

    // MARK: - Counts

    @Test("Only the counted states carry a number")
    func onlyCountedStatesCarryANumber() {
        #expect(service.message(for: .init(streakWeeks: 4), now: now).count == 4)
        #expect(service.message(for: .init(completedSessionDates: [daysAgo(1), daysAgo(2)]), now: now).count == 2)
        #expect(service.message(for: .init(), now: now).count == nil)
        #expect(service.message(for: .init(completedSessionDates: [now]), now: now).count == nil)
    }

    // MARK: - Variant determinism

    @Test("The same day always yields the same variant, so the line never flickers")
    func variantIsStableWithinADay() {
        let morning = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let night = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        #expect(service.message(for: .init(), now: morning).variant == service.message(for: .init(), now: night).variant)
    }

    @Test("Consecutive days yield different variants, so it does not go stale")
    func variantChangesAcrossDays() {
        let today = service.message(for: .init(), now: now).variant
        let tomorrow = service.message(for: .init(), now: calendar.date(byAdding: .day, value: 1, to: now)!).variant
        #expect(today != tomorrow)
    }

    @Test("Variant always indexes a real message")
    func variantStaysInRange() {
        for offset in 0..<400 {
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            let variant = service.message(for: .init(), now: date).variant
            #expect(variant >= 0)
            #expect(variant < CoachMessageService.variantCount)
        }
    }

    // MARK: - Localization wiring

    @Test("Every state and variant resolves to a real localized string")
    func everyMessageKeyExists() {
        for state in CoachMessageService.State.allCases {
            for variant in 0..<CoachMessageService.variantCount {
                let key = CoachMessageService.Message(state: state, variant: variant, count: nil).key
                let value = String(localized: String.LocalizationValue(key))
                // A missing key resolves back to the key itself.
                #expect(value != key, "missing localization for \(key)")
                #expect(value.isEmpty == false)
            }
        }
    }

    /// Regression: the named-greeting keys were briefly registered as
    /// "today.greeting.morning.named %@" while the lookup asked for
    /// "today.greeting.morning.named", so the greeting silently fell back to the raw key.
    @Test("Both greeting forms resolve, named and plain")
    func greetingKeysExist() {
        for slot in ["morning", "afternoon", "evening"] {
            let base = "today.greeting." + slot
            for key in [base, base + ".named"] {
                let value = String(localized: String.LocalizationValue(key))
                #expect(value != key, "missing localization for \(key)")
            }
        }
    }

    @Test("Named greetings carry exactly one string placeholder for the name")
    func namedGreetingsInterpolateTheName() {
        for slot in ["morning", "afternoon", "evening"] {
            // The key must be a plain String before it reaches LocalizationValue --
            // interpolating inline turns it into the key "today.greeting.%@.named",
            // which is the very bug this suite guards against.
            let key = "today.greeting." + slot + ".named"
            let template = String(localized: String.LocalizationValue(key))
            #expect(template.contains("%@"), "\(slot) named greeting has no name placeholder")
            let rendered = String(format: template, "Tar")
            #expect(rendered.contains("Tar"))
            #expect(rendered.contains("%@") == false)
        }
    }
}
