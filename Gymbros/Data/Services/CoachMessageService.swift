import Foundation

/// Picks the Today header's second line -- a short coaching line that reacts to where the
/// user actually is, replacing what used to be a fixed slogan.
///
/// Two deliberate properties:
///
/// 1. **Deterministic.** The variant comes from the calendar day, so the line is stable for
///    a whole day (it never flickers on redraw or changes under a pull-to-refresh) but
///    differs day to day. A static line becomes furniture within a week; a randomised one
///    can't be tested and jumps around while you're looking at it.
/// 2. **Never guilt-trips.** No state scolds the user for time off -- `comeback` and `away`
///    are warm on purpose. This is the "มาแค่นี้พอ" (just show up) principle in copy form.
///
/// Pure: no I/O, no clock access except the injected `now`.
struct CoachMessageService {
    static let variantCount = 3

    /// Ordered by priority -- `resolve` returns the first that matches.
    enum State: String, CaseIterable {
        /// Already trained today: celebrate and get out of the way. Never ask for more.
        case trainedToday = "trained_today"
        /// 14+ day gap. The comeback ramp is running; keep it low-pressure.
        case comeback
        /// 7-13 days away. Warm, no comment on the gap itself.
        case away
        /// A lift has stalled -- the one state that nudges toward more weight.
        case plateau
        /// 2+ consecutive weeks trained.
        case streak
        /// 2+ sessions already this week.
        case onARoll = "on_a_roll"
        /// Trained yesterday.
        case trainedYesterday = "trained_yesterday"
        /// Nothing special to say.
        case ready
    }

    struct Message: Equatable {
        let state: State
        let variant: Int
        /// Populated only for states whose copy interpolates a number.
        let count: Int?

        var key: String { "today.coach.\(state.rawValue).\(variant)" }
    }

    struct Input {
        var completedSessionDates: [Date]
        var streakWeeks: Int
        var isWelcomeBack: Bool
        var isComeback: Bool
        var hasStalledExercise: Bool

        init(
            completedSessionDates: [Date] = [],
            streakWeeks: Int = 0,
            isWelcomeBack: Bool = false,
            isComeback: Bool = false,
            hasStalledExercise: Bool = false
        ) {
            self.completedSessionDates = completedSessionDates
            self.streakWeeks = streakWeeks
            self.isWelcomeBack = isWelcomeBack
            self.isComeback = isComeback
            self.hasStalledExercise = hasStalledExercise
        }
    }

    /// ISO-8601 to match `StreakService` and the week strip, so "this week" means one
    /// thing everywhere on the Today screen.
    private let calendar = Calendar(identifier: .iso8601)

    func message(for input: Input, now: Date = .now) -> Message {
        let state = resolve(input, now: now)
        return Message(
            state: state,
            variant: variant(for: now),
            count: count(for: state, input: input, now: now)
        )
    }

    func resolve(_ input: Input, now: Date = .now) -> State {
        if trainedToday(input, now: now) { return .trainedToday }
        if input.isComeback { return .comeback }
        if input.isWelcomeBack { return .away }
        if input.hasStalledExercise { return .plateau }
        if input.streakWeeks >= 2 { return .streak }
        if sessionsThisWeek(input, now: now) >= 2 { return .onARoll }
        if trainedYesterday(input, now: now) { return .trainedYesterday }
        return .ready
    }

    private func count(for state: State, input: Input, now: Date) -> Int? {
        switch state {
        case .streak:
            return input.streakWeeks
        case .onARoll:
            return sessionsThisWeek(input, now: now)
        case .trainedToday, .comeback, .away, .plateau, .trainedYesterday, .ready:
            return nil
        }
    }

    /// Day-of-year modulo the variant count. Falls back to 0 if the calendar can't produce
    /// an ordinality, which keeps this total rather than crashing on an edge date.
    private func variant(for now: Date) -> Int {
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        return (dayOfYear - 1) % Self.variantCount
    }

    private func trainedToday(_ input: Input, now: Date) -> Bool {
        input.completedSessionDates.contains { calendar.isDate($0, inSameDayAs: now) }
    }

    private func trainedYesterday(_ input: Input, now: Date) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return false }
        return input.completedSessionDates.contains { calendar.isDate($0, inSameDayAs: yesterday) }
    }

    /// Distinct *days* trained, not raw session count -- two sessions in one day is one day
    /// of work, and counting them separately would overstate the week.
    private func sessionsThisWeek(_ input: Input, now: Date) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        let days = input.completedSessionDates
            .filter { week.contains($0) }
            .map { calendar.startOfDay(for: $0) }
        return Set(days).count
    }
}
