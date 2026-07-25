import SwiftUI

struct TodayView: View {
    @State var viewModel: TodayViewModel
    @Binding var deepLinkedWorkoutRoute: WorkoutLaunchRoute?
    let date: Date
    let onShowPrograms: () -> Void
    private let loadsOnAppear: Bool

    @Environment(AppPreferences.self) private var appPreferences
    @State private var selectedWorkoutRoute: WorkoutLaunchRoute?
    @State private var didLogComebackCardShown = false
    @State private var selectedDay: ProgramDay?

    @MainActor
    init(
        viewModel: TodayViewModel? = nil,
        deepLinkedWorkoutRoute: Binding<WorkoutLaunchRoute?> = .constant(nil),
        date: Date = .now,
        loadsOnAppear: Bool = true,
        onShowPrograms: @escaping () -> Void = {}
    ) {
        self._viewModel = State(initialValue: viewModel ?? TodayViewModel())
        self._deepLinkedWorkoutRoute = deepLinkedWorkoutRoute
        self.date = date
        self.loadsOnAppear = loadsOnAppear
        self.onShowPrograms = onShowPrograms
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
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    brandHeader

                    if data.isWelcomeBack, let nextDay = data.nextDay {
                        welcomeBackBanner(dayName: (selectedDay ?? nextDay).name)
                    }

                    if let nextDay = data.nextDay {
                        let displayedDay = selectedDay ?? nextDay
                        if let program = data.activeProgram {
                            changeDayMenu(days: program.days, currentDay: displayedDay)
                        }
                        if data.recommendation.mode.isComeback {
                            comebackCard(data: data, nextDay: displayedDay)
                        } else {
                            nextWorkoutCard(data: data, nextDay: displayedDay)
                            if let stalled = data.stalledExercise {
                                overloadAdvisorCard(stalled)
                            }
                        }
                    }
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .brandHeroWash()
        }
    }

    /// Brand hero header: greeting line + the big date, sitting directly on the
    /// ambient wash (no card) -- the mockup's "Hey / Just show up. / 08.04" block.
    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.brandSparkLime, .brandHeroViolet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(greetingKey)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("today.brand.tagline")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(brandDateText)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                Text(date, format: .dateTime.weekday(.wide))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func changeDayMenu(days: [ProgramDay], currentDay: ProgramDay) -> some View {
        // Excludes whatever day is currently displayed (the default recommendation, or a
        // previously-picked alternate) so the picked-away-from day is always reachable
        // again -- excluding only the original recommendation would permanently remove it
        // from this list the moment the user picked something else.
        let otherDays = days
            .sorted { $0.dayOrder < $1.dayOrder }
            .filter { $0.id != currentDay.id }
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

    private func welcomeBackBanner(dayName: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.wave.fill")
                .foregroundStyle(.secondary)
                .font(.title3)
                .accessibilityHidden(true)

            Text("today.welcome_back \(dayName)")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

                    Text(nextDay.name)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                if data.streakWeeks >= 2 {
                    streakBadge(weeks: data.streakWeeks)
                }
            }

            exercisePreview(for: nextDay)

            if let lastSessionDate = data.lastSessionDate {
                Text("today.last_workout \(lastSessionDate.relativeString)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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

    private func exercisePreview(for day: ProgramDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("programDetail.exerciseCount \(day.exercises.count)")
                .font(.subheadline)
                .foregroundStyle(.primary)

            ForEach(day.exercises.prefix(3)) { exercise in
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Text(exerciseSummary(exercise))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func exerciseSummary(_ exercise: ProgramExercise) -> String {
        let sets = String(format: String(localized: "programExercise.setsFormat"), exercise.targetSets)
        let reps = String(
            format: String(localized: "programExercise.repsFormat"),
            exercise.targetRepsMin,
            exercise.targetRepsMax
        )
        let rest = String(format: String(localized: "programExercise.restFormat"), exercise.targetRestSeconds)
        return [sets, reps, rest].joined(separator: " • ")
    }

    /// Day.month, dot-separated (e.g. "08.04") -- the brand header's big date.
    /// Uses a fixed numeric format rather than a locale date style so the mark stays
    /// visually consistent across TH/EN; the weekday below it stays localized.
    private var brandDateText: String {
        let components = Calendar.autoupdatingCurrent.dateComponents([.day, .month], from: date)
        return String(format: "%02d.%02d", components.day ?? 1, components.month ?? 1)
    }

    private var greetingKey: LocalizedStringKey {
        switch Calendar.autoupdatingCurrent.component(.hour, from: date) {
        case 5..<12:
            "today.greeting.morning"
        case 12..<17:
            "today.greeting.afternoon"
        default:
            "today.greeting.evening"
        }
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

#Preview("Has Program With Streak") {
    NavigationStack {
        TodayView(viewModel: .hasProgramWithStreak, date: TodayViewModel.afternoon, loadsOnAppear: false)
    }
}

#Preview("Welcome Back") {
    NavigationStack {
        TodayView(viewModel: .welcomeBack, date: TodayViewModel.evening, loadsOnAppear: false)
    }
}
