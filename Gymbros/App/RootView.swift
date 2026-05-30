import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var auth: AuthService
    @State private var appPreferences: AppPreferences

    @MainActor
    init(auth: AuthService? = nil, appPreferences: AppPreferences? = nil) {
        self._auth = State(initialValue: auth ?? .shared)
        self._appPreferences = State(initialValue: appPreferences ?? .shared)
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

                    NavigationStack {
                        SettingsView(viewModel: SettingsViewModel(authService: auth, appPreferences: appPreferences))
                    }
                    .tabItem {
                        Label("settings.title", systemImage: "gear")
                    }
                    .tag(3)
                }
            } else {
                SignInView()
            }
        }
        .environment(appPreferences)
        .task {
            await auth.loadCurrentSession()
            await refreshPreferencesIfAuthenticated()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await auth.loadCurrentSession()
                await refreshPreferencesIfAuthenticated()
            }
        }
        .onChange(of: auth.isAuthenticated) { _, _ in
            Task { await refreshPreferencesIfAuthenticated() }
        }
    }

    private func refreshPreferencesIfAuthenticated() async {
        guard auth.isAuthenticated else {
            appPreferences.reset()
            return
        }
        await appPreferences.refresh()
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
    RootView(auth: MockAuthService(isAuthenticated: true), appPreferences: AppPreferences())
}

#Preview("Unauthenticated") {
    RootView(auth: MockAuthService(isAuthenticated: false), appPreferences: AppPreferences())
}
#endif
