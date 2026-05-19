import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var auth: AuthService

    init(auth: AuthService = .shared) {
        self._auth = State(initialValue: auth)
    }

    var body: some View {
        Group {
            if auth.isAuthenticated {
                TabView {
                    NavigationStack {
                        TodayView()
                    }
                    .tabItem {
                        Label("today.title", systemImage: "house")
                    }

                    NavigationStack {
                        ProgramListView(viewModel: ProgramListViewModel())
                    }
                    .tabItem {
                        Label("programs.title", systemImage: "list.bullet")
                    }

                    NavigationStack {
                        HistoryView(state: .loading)
                    }
                    .tabItem {
                        Label("history.title", systemImage: "clock")
                    }
                }
            } else {
                SignInView()
            }
        }
        .task {
            await auth.loadCurrentSession()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await auth.loadCurrentSession() }
        }
    }
}

#if DEBUG
@MainActor
private final class MockAuthService: AuthService {
    private let _isAuthenticated: Bool
    override var isAuthenticated: Bool { _isAuthenticated }

    init(isAuthenticated: Bool) {
        self._isAuthenticated = isAuthenticated
        super.init()
    }

    override func loadCurrentSession() async {}
}

#Preview("Authenticated") {
    RootView(auth: MockAuthService(isAuthenticated: true))
}

#Preview("Unauthenticated") {
    RootView(auth: MockAuthService(isAuthenticated: false))
}
#endif
