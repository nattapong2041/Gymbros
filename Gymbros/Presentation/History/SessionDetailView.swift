import SwiftUI

struct SessionDetailView: View {
    @State var viewModel: SessionDetailViewModel
    private let loadsOnAppear: Bool

    @MainActor
    init(viewModel: SessionDetailViewModel, loadsOnAppear: Bool = true) {
        self._viewModel = State(initialValue: viewModel)
        self.loadsOnAppear = loadsOnAppear
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                ContentUnavailableView(
                    "session.exercise.unknown",
                    systemImage: "list.bullet.clipboard"
                )
            case .error(let error):
                ContentUnavailableView {
                    Label(LocalizedStringKey(error.titleKey), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(LocalizedStringKey(error.messageKey))
                } actions: {
                    Button("common.retry", systemImage: "arrow.clockwise") {
                        Task { await viewModel.load() }
                    }
                }
            case .success(let data):
                List {
                    Section {
                        Text(durationText(for: data.session))
                            .font(.subheadline)
                    }

                    ForEach(exerciseGroups(from: data), id: \.id) { group in
                        Section {
                            ForEach(group.sets) { set in
                                SessionSetRow(workoutSet: set)
                            }
                        } header: {
                            Text(group.name)
                        }
                    }
                }
                .navigationTitle(data.session.startedAt.workoutDisplayString)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task {
            guard loadsOnAppear else { return }
            await viewModel.load()
        }
    }

    private func durationText(for session: WorkoutSession) -> String {
        String(
            format: String(localized: "session.duration"),
            durationMinutes(for: session)
        )
    }

    private func durationMinutes(for session: WorkoutSession) -> Int {
        guard let duration = session.duration else { return 0 }
        return max(1, Int(duration / 60))
    }

    private func exerciseGroups(from data: SessionDetailData) -> [SessionExerciseSetGroup] {
        Dictionary(grouping: data.sets) { $0.exerciseId }
            .map { exerciseId, sets in
                SessionExerciseSetGroup(
                    id: exerciseId,
                    name: data.exerciseLookup[exerciseId]?.displayName ?? String(localized: "session.exercise.unknown"),
                    sets: sets.sorted { $0.setNumber < $1.setNumber }
                )
            }
            .sorted { lhs, rhs in
                guard let lhsFirstSet = lhs.sets.first, let rhsFirstSet = rhs.sets.first else {
                    return lhs.name < rhs.name
                }
                return lhsFirstSet.completedAt < rhsFirstSet.completedAt
            }
    }
}

#Preview("Loading") {
    NavigationStack {
        SessionDetailView(viewModel: .loading, loadsOnAppear: false)
    }
}

#Preview("Error") {
    NavigationStack {
        SessionDetailView(viewModel: .error, loadsOnAppear: false)
    }
}

#Preview("Success") {
    NavigationStack {
        SessionDetailView(viewModel: .success, loadsOnAppear: false)
    }
}
