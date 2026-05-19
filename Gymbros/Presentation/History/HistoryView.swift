import SwiftUI

struct HistoryView: View {
    let state: ViewState<HistoryDisplayData>
    var onRetry: () -> Void = {}
    var onRetrySessionDetail: (WorkoutSession) -> Void = { _ in }

    var body: some View {
        Group {
            switch state {
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
                    Button("common.retry", systemImage: "arrow.clockwise", action: onRetry)
                }
            case .success(let data):
                List {
                    ForEach(data.sessions) { session in
                        NavigationLink(value: session.id) {
                            HistorySessionRow(
                                session: session,
                                dayName: data.dayName(for: session)
                            )
                        }
                    }
                }
                .refreshable {
                    onRetry()
                }
                .navigationDestination(for: UUID.self) { sessionId in
                    if let session = data.sessions.first(where: { $0.id == sessionId }) {
                        SessionDetailView(
                            state: data.detailState(for: session),
                            onRetry: { onRetrySessionDetail(session) }
                        )
                    } else {
                        SessionDetailView(
                            state: .error(.notFound),
                            onRetry: {}
                        )
                    }
                }
            }
        }
        .navigationTitle("history.title")
    }
}

#Preview("Loading") {
    NavigationStack {
        HistoryView(state: .loading)
    }
}

#Preview("Empty") {
    NavigationStack {
        HistoryView(state: .empty)
    }
}

#Preview("Error") {
    NavigationStack {
        HistoryView(state: .error(.network(.offline)))
    }
}

#Preview("Success") {
    NavigationStack {
        HistoryView(state: .success(.mock))
    }
}
