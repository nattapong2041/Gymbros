import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var auth: AuthService

    @MainActor
    init(auth: AuthService? = nil) {
        self._auth = State(initialValue: auth ?? .shared)
    }

    @State private var selectedTab = 0

    var body: some View {
        Group {
            if auth.isAuthenticated {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        TodayView(onShowPrograms: { selectedTab = 1 })
                    }
                    .tabItem {
                        Label("today.title", systemImage: "house")
                    }
                    .tag(0)

                    NavigationStack {
                        ProgramListView(viewModel: ProgramListViewModel())
                    }
                    .tabItem {
                        Label("programs.title", systemImage: "list.bullet")
                    }
                    .tag(1)

                    NavigationStack {
                        HistoryView(viewModel: HistoryViewModel())
                    }
                    .tabItem {
                        Label("history.title", systemImage: "clock")
                    }
                    .tag(2)
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
