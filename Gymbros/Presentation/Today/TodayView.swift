import SwiftUI

struct TodayViewData {
    var activeProgram: Program?
    var nextDay: ProgramDay?
    var recentSessions: [WorkoutSession]
    var streakWeeks: Int
    var lastSessionDate: Date?
    var isWelcomeBack: Bool
}

struct TodayView: View {
    let state: ViewState<TodayViewData>
    let date: Date
    let onRetry: () -> Void
    let onShowPrograms: () -> Void

    @State private var selectedProgramDayId: UUID?

    init(
        state: ViewState<TodayViewData> = .loading,
        date: Date = .now,
        onRetry: @escaping () -> Void = {},
        onShowPrograms: @escaping () -> Void = {}
    ) {
        self.state = state
        self.date = date
        self.onRetry = onRetry
        self.onShowPrograms = onShowPrograms
    }

    var body: some View {
        content
            .navigationTitle("today.title")
            .navigationDestination(item: $selectedProgramDayId) { programDayId in
                WorkoutSessionScreen(programDayId: programDayId)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
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
    private func successState(_ data: TodayViewData) -> some View {
        if data.activeProgram == nil || data.nextDay == nil {
            noProgramState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(greetingKey)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)

                    if data.isWelcomeBack {
                        welcomeBackBanner
                    }

                    if let nextDay = data.nextDay {
                        nextWorkoutCard(data: data, nextDay: nextDay)
                    }
                }
                .padding()
            }
            .background(Color.gymBackground)
        }
    }

    private var noProgramState: some View {
        ContentUnavailableView {
            Label("today.empty.no_program", systemImage: "figure.strengthtraining.traditional")
        } actions: {
            Button("today.empty.programs_cta", action: onShowPrograms)
                .buttonStyle(TodaySecondaryButtonStyle())
        }
    }

    private func errorState(_ error: AppError) -> some View {
        ContentUnavailableView {
            Label(LocalizedStringKey(error.titleKey), systemImage: "exclamationmark.triangle")
        } description: {
            Text(LocalizedStringKey(error.messageKey))
        } actions: {
            Button("common.retry", action: onRetry)
                .buttonStyle(TodaySecondaryButtonStyle())
        }
    }

    private var welcomeBackBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.wave.fill")
                .foregroundStyle(.blue)
                .font(.title3)
                .accessibilityHidden(true)

            Text("today.welcome_back")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func nextWorkoutCard(data: TodayViewData, nextDay: ProgramDay) -> some View {
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
                selectedProgramDayId = nextDay.id
            } label: {
                Label("today.start_cta", systemImage: "play.fill")
                    .font(.headline)
            }
            .buttonStyle(TodayPrimaryButtonStyle())
            .accessibilityLabel(Text("accessibility.today.start \(nextDay.name)"))
        }
        .padding()
        .background(Color.gymSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func streakBadge(weeks: Int) -> some View {
        Label {
            Text("today.streak.weeks \(weeks)")
                .font(.caption.bold())
                .lineLimit(1)
        } icon: {
            Image(systemName: "checkmark.seal.fill")
                .accessibilityHidden(true)
        }
        .foregroundStyle(.green)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary, in: Capsule())
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

private struct TodayPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(.blue.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(.white)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct TodaySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(.blue.opacity(configuration.isPressed ? 0.12 : 0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(.blue)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview("Loading") {
    NavigationStack {
        TodayView(state: .loading)
    }
}

#Preview("Error") {
    NavigationStack {
        TodayView(state: .error(.network(.offline)))
    }
}

#Preview("No Program") {
    NavigationStack {
        TodayView(state: .success(.noProgram))
    }
}

#Preview("Has Program, No History") {
    NavigationStack {
        TodayView(state: .success(.hasProgramNoHistory), date: TodayMockData.morning)
    }
}

#Preview("Has Program With Streak") {
    NavigationStack {
        TodayView(state: .success(.hasProgramWithStreak), date: TodayMockData.afternoon)
    }
}

#Preview("Welcome Back") {
    NavigationStack {
        TodayView(state: .success(.welcomeBack), date: TodayMockData.evening)
    }
}
