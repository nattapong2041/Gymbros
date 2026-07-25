import SwiftUI

struct TodayView: View {
    @State var viewModel: TodayViewModel
    @Binding var deepLinkedWorkoutRoute: WorkoutLaunchRoute?
    let date: Date
    let onShowPrograms: () -> Void
    let onShowSettings: () -> Void
    private let loadsOnAppear: Bool

    @Environment(AppPreferences.self) private var appPreferences
    @State private var selectedWorkoutRoute: WorkoutLaunchRoute?
    @State private var didLogComebackCardShown = false
    @State private var selectedDay: ProgramDay?
    private let coachMessageService = CoachMessageService()

    @MainActor
    init(
        viewModel: TodayViewModel? = nil,
        deepLinkedWorkoutRoute: Binding<WorkoutLaunchRoute?> = .constant(nil),
        date: Date = .now,
        loadsOnAppear: Bool = true,
        onShowPrograms: @escaping () -> Void = {},
        onShowSettings: @escaping () -> Void = {}
    ) {
        self._viewModel = State(initialValue: viewModel ?? TodayViewModel())
        self._deepLinkedWorkoutRoute = deepLinkedWorkoutRoute
        self.date = date
        self.loadsOnAppear = loadsOnAppear
        self.onShowPrograms = onShowPrograms
        self.onShowSettings = onShowSettings
    }

    var body: some View {
        content
            .navigationTitle("today.title")
            // The brand header carries the screen identity; a large nav title would
            // duplicate it. Inline keeps the title for accessibility/back-navigation
            // without a second heading on screen.
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedWorkoutRoute) { route in
                WorkoutSessionScreen(
                    programDayId: route.programDayId,
                    initialProgramExerciseId: route.programExerciseId,
                    recommendation: viewModel.state.value?.recommendation ?? .normalDefault
                )
            }
            // In normal mode the day picker is the card's day name itself, so it needs no
            // toolbar slot. The comeback card never shows a day name (it leads with the
            // welcome-back message), leaving nothing to attach the menu to -- so that one
            // mode keeps the toolbar item rather than losing day-switching entirely.
            .toolbar {
                if let data = viewModel.state.value,
                   data.recommendation.mode.isComeback,
                   let program = data.activeProgram,
                   let nextDay = data.nextDay {
                    ToolbarItem(placement: .topBarTrailing) {
                        changeDayMenu(days: program.days, currentDay: selectedDay ?? nextDay)
                    }
                }
            }
            .task {
                guard loadsOnAppear else { return }
                await viewModel.load()
            }
            .onChange(of: deepLinkedWorkoutRoute) { _, route in
                guard let route else { return }
                selectedWorkoutRoute = route
                deepLinkedWorkoutRoute = nil
            }
            .onChange(of: viewModel.state.value?.nextDay?.id) { _, _ in
                selectedDay = nil
            }
            .refreshable {
                guard loadsOnAppear else { return }
                await viewModel.refresh()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .empty:
            noProgramState
        case .error(let error):
            errorState(error)
        case .success(let data):
            successState(data)
        }
    }

    @ViewBuilder
    private func successState(_ data: TodayData) -> some View {
        if data.activeProgram == nil || data.nextDay == nil {
            noProgramState
        } else if let nextDay = data.nextDay {
            let displayedDay = selectedDay ?? nextDay
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    brandHeader(data: data)

                    // Sits with the header block, above the cards: it's status ("where am
                    // I this week?"), which belongs next to the date rather than below the
                    // call to action. Deliberately chrome-less and compact -- a full card
                    // here would push the advisor card back off the bottom of the screen.
                    WeekActivityStripView(
                        completedDates: data.recentSessions.map(\.startedAt),
                        today: date
                    )

                    if data.recommendation.mode.isComeback {
                        comebackCard(data: data, nextDay: displayedDay)
                    } else {
                        nextWorkoutCard(data: data, nextDay: displayedDay)
                        if let stalled = data.stalledExercise {
                            overloadAdvisorCard(stalled)
                        }
                    }
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .brandHeroWash()
        }
    }

    /// Brand hero header: greeting line + the date, sitting directly on the ambient
    /// wash (no card). The welcome-back message replaces the greeting line rather than
    /// adding a separate banner below it -- they occupy the same register, and folding
    /// one into the other is what makes the worst-case screen (welcome-back + card +
    /// advisor card) fit without scrolling.
    private func brandHeader(data: TodayData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                avatarButton(profileName: data.profileName)

                VStack(alignment: .leading, spacing: 2) {
                    Text(greetingText(profileName: data.profileName))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    // The slot the static tagline used to occupy -- now a line that
                    // actually reacts to where the user is. See CoachMessageService.
                    Text(coachMessageText(for: data))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(brandDateText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                Text(date, format: .dateTime.weekday(.wide))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The gradient avatar is a real control, not decoration: it's circular, 44pt and in
    /// the top-left, so it reads as a tappable avatar -- it should behave like one rather
    /// than swallow the tap. Shows the profile's initial when there is a name, and a
    /// person glyph when there isn't.
    private func avatarButton(profileName: String?) -> some View {
        Button(action: onShowSettings) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.brandSparkLime, .brandHeroViolet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let initial = profileInitial(from: profileName) {
                    Text(initial)
                        .font(.system(.title3, design: .rounded).bold())
                        // Dark-on-gradient: the lime end of this gradient can never sit
                        // behind white text.
                        .foregroundStyle(Color.black.opacity(0.82))
                } else {
                    Image(systemName: "person.fill")
                        .font(.body)
                        .foregroundStyle(Color.black.opacity(0.72))
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("accessibility.today.profile"))
    }

    private func profileInitial(from name: String?) -> String? {
        guard let first = name?.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return nil
        }
        return String(first).uppercased()
    }

    /// The card's day name doubles as the day picker (Calendar-app style): the control
    /// sits directly on what it changes and costs no extra height. Falls back to plain
    /// text when there's no other day to switch to, so a one-day program shows no
    /// affordance that would do nothing.
    @ViewBuilder
    private func dayNameMenu(days: [ProgramDay], currentDay: ProgramDay) -> some View {
        let otherDays = alternateDays(from: days, currentDay: currentDay)

        if otherDays.isEmpty {
            Text(currentDay.name)
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)
        } else {
            Menu {
                ForEach(otherDays) { day in
                    Button(day.name) { selectedDay = day }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentDay.name)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(Text("accessibility.today.change_day \(currentDay.name)"))
        }
    }

    /// Excludes whatever day is currently displayed (the default recommendation, or a
    /// previously-picked alternate) so the picked-away-from day is always reachable
    /// again -- excluding only the original recommendation would permanently remove it
    /// from this list the moment the user picked something else.
    private func alternateDays(from days: [ProgramDay], currentDay: ProgramDay) -> [ProgramDay] {
        days
            .sorted { $0.dayOrder < $1.dayOrder }
            .filter { $0.id != currentDay.id }
    }

    @ViewBuilder
    private func changeDayMenu(days: [ProgramDay], currentDay: ProgramDay) -> some View {
        let otherDays = alternateDays(from: days, currentDay: currentDay)
        if otherDays.isEmpty == false {
            Menu {
                ForEach(otherDays) { day in
                    Button(day.name) {
                        selectedDay = day
                    }
                }
            } label: {
                Label("today.change_day.button", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
            }
            .frame(minHeight: 48)
        }
    }

    private var noProgramState: some View {
        ContentUnavailableView {
            Label("today.empty.no_program", systemImage: "figure.strengthtraining.traditional")
        } actions: {
            Button("today.empty.programs_cta", action: onShowPrograms)
                .buttonStyle(.bordered)
        }
    }

    private func errorState(_ error: AppError) -> some View {
        ContentUnavailableView {
            Label(LocalizedStringKey(error.titleKey), systemImage: "exclamationmark.triangle")
        } description: {
            Text(LocalizedStringKey(error.messageKey))
        } actions: {
            Button("common.retry") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.bordered)
        }
    }

    private func comebackCard(data: TodayData, nextDay: ProgramDay) -> some View {
        ComebackCardView(recommendation: data.recommendation) {
            selectedWorkoutRoute = WorkoutLaunchRoute(
                programDayId: nextDay.id,
                programExerciseId: nil,
                sessionId: nil
            )
        }
        .onAppear {
            guard didLogComebackCardShown == false else { return }
            didLogComebackCardShown = true
            viewModel.trackComebackCardShown()
        }
    }

    private func nextWorkoutCard(data: TodayData, nextDay: ProgramDay) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("today.next_workout.title")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    dayNameMenu(days: data.activeProgram?.days ?? [], currentDay: nextDay)
                }

                Spacer(minLength: 12)

                if data.streakWeeks >= 2 {
                    streakBadge(weeks: data.streakWeeks)
                }
            }

            exercisePreview(for: nextDay)

            // "Last workout N hours ago" used to live here. The week strip above now shows
            // the same thing visually and more completely, so this was both redundant and
            // ~36pt of the height that pushed the advisor card off the screen.

            Button {
                selectedWorkoutRoute = WorkoutLaunchRoute(
                    programDayId: nextDay.id,
                    programExerciseId: nil,
                    sessionId: nil
                )
            } label: {
                Label("today.start_cta", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    // Glass must be applied INSIDE the label, and the shape made
                    // explicit -- wrapping the Button in the glass modifier swallowed
                    // the hit region and made Start untappable.
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel(Text("accessibility.today.start \(nextDay.name)"))
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func overloadAdvisorCard(_ stalled: StalledExercise) -> some View {
        OverloadAdvisorCardView(
            exerciseName: stalled.exerciseName,
            weightText: appPreferences.weightUnit.formattedKilograms(stalled.weight),
            weightUnitAbbreviation: appPreferences.weightUnit.localizedAbbreviation,
            onTryNextTime: {
                Task { await viewModel.tryOverloadSuggestion(stalled) }
            },
            onNotNow: {
                viewModel.snoozeOverloadSuggestion(stalled)
            }
        )
    }

    private func streakBadge(weeks: Int) -> some View {
        BrandSparkBadge(systemImage: "bolt.fill", text: "today.streak.weeks \(weeks)")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("accessibility.today.streak \(weeks)"))
    }

    // Collapsed from a per-exercise list to one summary line: the per-exercise rows had
    // no exercise name (ProgramExercise only carries an id, not a name lookup), so three
    // near-identical "3 เซ็ต • 7-8 ครั้ง • พัก 150 วิ" rows identified nothing.
    private func exercisePreview(for day: ProgramDay) -> some View {
        HStack(spacing: 8) {
            Text("programDetail.exerciseCount \(day.exercises.count)")
                .font(.subheadline)
                .foregroundStyle(.primary)

            // verbatim: a bare Text("•") would be extracted as a translatable key.
            Text(verbatim: "•")
                .foregroundStyle(.secondary)

            Text("today.next_workout.set_summary \(totalSets(in: day))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func totalSets(in day: ProgramDay) -> Int {
        day.exercises.reduce(0) { $0 + $1.targetSets }
    }

    /// Day.month, dot-separated (e.g. "08.04") -- the brand header's big date.
    /// Uses a fixed numeric format rather than a locale date style so the mark stays
    /// visually consistent across TH/EN; the weekday below it stays localized.
    private var brandDateText: String {
        let components = Calendar.autoupdatingCurrent.dateComponents([.day, .month], from: date)
        return String(format: "%02d.%02d", components.day ?? 1, components.month ?? 1)
    }

    private var greetingKey: String {
        switch Calendar.autoupdatingCurrent.component(.hour, from: date) {
        case 5..<12:
            "today.greeting.morning"
        case 12..<17:
            "today.greeting.afternoon"
        default:
            "today.greeting.evening"
        }
    }

    /// Greets by name when the profile has one, and falls back to the plain time-of-day
    /// greeting when it doesn't -- rather than showing an awkward empty slot.
    ///
    /// The key is assembled into a `String` *before* it reaches `LocalizationValue`.
    /// Interpolating directly (`LocalizationValue("\(key).named")`) makes the compiler
    /// treat the interpolated part as a format argument, so the extracted key collapses
    /// to a literal "%@.named" and the real key is never looked up.
    private func greetingText(profileName: String?) -> String {
        let trimmed = profileName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.isEmpty == false else {
            return String(localized: String.LocalizationValue(greetingKey))
        }
        let namedKey = greetingKey + ".named"
        return String(format: String(localized: String.LocalizationValue(namedKey)), trimmed)
    }

    private func coachMessageText(for data: TodayData) -> String {
        let message = coachMessageService.message(
            for: CoachMessageService.Input(
                completedSessionDates: data.recentSessions.map(\.startedAt),
                streakWeeks: data.streakWeeks,
                isWelcomeBack: data.isWelcomeBack,
                isComeback: data.recommendation.mode.isComeback,
                hasStalledExercise: data.stalledExercise != nil
            ),
            now: date
        )

        let template = String(localized: String.LocalizationValue(message.key))
        guard let count = message.count else { return template }
        return String(format: template, count)
    }
}

#Preview("Loading") {
    NavigationStack {
        TodayView(viewModel: .loading, loadsOnAppear: false)
    }
}

#Preview("Error") {
    NavigationStack {
        TodayView(viewModel: .error, loadsOnAppear: false)
    }
}

#Preview("No Program") {
    NavigationStack {
        TodayView(viewModel: .noProgram, loadsOnAppear: false)
    }
}

#Preview("Has Program, No History") {
    NavigationStack {
        TodayView(viewModel: .hasProgramNoHistory, date: TodayViewModel.morning, loadsOnAppear: false)
    }
}

#Preview("Welcome Back") {
    NavigationStack {
        TodayView(viewModel: .welcomeBack, date: TodayViewModel.evening, loadsOnAppear: false)
    }
}

// ---------------------------------------------------------------------------------
// Fit checks. These two are the pair to compare: same screen, advisor card absent vs
// present. Both are wrapped in a real TabView because RootView is the only other place
// TodayView gets a tab bar from -- inside a bare NavigationStack no tab bar renders and
// the preview cannot show whether anything is clipped by it.
//
// Pass = every widget fully visible above the tab bar, no scrolling, at default
// Dynamic Type. At accessibility text sizes it will scroll, which is correct.
// ---------------------------------------------------------------------------------

#Preview("FIT · No Advisor Card") {
    TabView {
        NavigationStack {
            TodayView(viewModel: .hasProgramWithStreak, date: TodayViewModel.afternoon, loadsOnAppear: false)
        }
        .tabItem {
            Label("today.title", systemImage: "house")
        }
    }
}

#Preview("FIT · With Advisor Card") {
    TabView {
        NavigationStack {
            TodayView(viewModel: .stalledWithWelcomeBack, date: TodayViewModel.afternoon, loadsOnAppear: false)
        }
        .tabItem {
            Label("today.title", systemImage: "house")
        }
    }
}

#Preview("Comeback: Change Day Toolbar") {
    TabView {
        NavigationStack {
            TodayView(viewModel: .comeback, date: TodayViewModel.morning, loadsOnAppear: false)
        }
        .tabItem {
            Label("today.title", systemImage: "house")
        }
    }
}
