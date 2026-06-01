import SwiftUI

struct HistoryView: View {
    @State var viewModel: HistoryViewModel
    @State private var sessionToDelete: WorkoutSession?
    private let loadsOnAppear: Bool

    @MainActor
    init(viewModel: HistoryViewModel? = nil, loadsOnAppear: Bool = true) {
        self._viewModel = State(initialValue: viewModel ?? HistoryViewModel())
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
                    "history.empty",
                    systemImage: "clock.arrow.circlepath"
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
                    ForEach(data.sessions) { session in
                        NavigationLink(value: session.id) {
                            HistorySessionRow(
                                session: session,
                                dayName: dayName(for: session, in: data)
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                sessionToDelete = session
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
                .refreshable {
                    guard loadsOnAppear else { return }
                    await viewModel.load()
                }
                .navigationDestination(for: UUID.self) { sessionId in
                    if let session = data.sessions.first(where: { $0.id == sessionId }) {
                        SessionDetailView(viewModel: SessionDetailViewModel(session: session))
                    } else {
                        // Fallback for edge cases where session ID is lost
                        ContentUnavailableView(
                            LocalizedStringKey("session.exercise.unknown"),
                            systemImage: "exclamationmark.triangle"
                        )
                    }
                }
            }
        }
        .navigationTitle("history.title")
        .alert(
            "history.delete.confirmation.title",
            isPresented: Binding(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            ),
            presenting: sessionToDelete
        ) { session in
            Button("common.delete", role: .destructive) {
                Task { await viewModel.deleteSession(session) }
            }
            .tint(.red)
            Button("common.cancel", role: .cancel) {}
        } message: { _ in
            Text("history.delete.confirmation.message")
        }
        .transientErrorAlert(error: Binding(
            get: { viewModel.transientError },
            set: { viewModel.transientError = $0 }
        ))
        .task {
            guard loadsOnAppear else { return }
            await viewModel.load()
        }
    }

    private func dayName(for session: WorkoutSession, in data: HistoryData) -> String? {
        guard let programDayId = session.programDayId else { return nil }
        return data.dayNames[programDayId]
    }
}

#Preview("Loading") {
    NavigationStack {
        HistoryView(viewModel: .loading, loadsOnAppear: false)
    }
}

#Preview("Empty") {
    NavigationStack {
        HistoryView(viewModel: .empty, loadsOnAppear: false)
    }
}

#Preview("Error") {
    NavigationStack {
        HistoryView(viewModel: .error, loadsOnAppear: false)
    }
}

#Preview("Success") {
    NavigationStack {
        HistoryView(viewModel: .success, loadsOnAppear: false)
    }
}
