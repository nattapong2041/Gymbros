import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var auth: AuthService
    @State private var appPreferences: AppPreferences
    @State private var deepLinkCoordinator = DeepLinkCoordinator.shared
    @State private var activeWorkoutWidget = ActiveWorkoutWidgetViewModel()
    @State private var isShowingActiveWorkoutStopConfirmation = false

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
                        TodayView(
                            deepLinkedWorkoutRoute: Binding(
                                get: { deepLinkCoordinator.pendingWorkoutRoute },
                                set: { deepLinkCoordinator.pendingWorkoutRoute = $0 }
                            ),
                            onShowPrograms: { selectedTab = 1 }
                        )
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
                .overlay(alignment: .bottom) {
                    if let snapshot = activeWorkoutWidget.visibleSnapshot {
                        ActiveWorkoutWidgetView(
                            snapshot: snapshot,
                            weightUnit: appPreferences.weightUnit
                        ) { route in
                            deepLinkCoordinator.pendingWorkoutRoute = route
                        } onStop: {
                            isShowingActiveWorkoutStopConfirmation = true
                        }
                        .frame(maxWidth: 460)
                        .padding(.horizontal, 16)
                        .offset(y: -84)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            } else {
                SignInView()
            }
        }
        .environment(appPreferences)
        .dismissKeyboardOnTap()
        .task {
            await auth.loadCurrentSession()
            await refreshPreferencesIfAuthenticated()
            refreshActiveWorkoutWidget()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await auth.loadCurrentSession()
                await refreshPreferencesIfAuthenticated()
                refreshActiveWorkoutWidget()
            }
        }
        .onChange(of: auth.isAuthenticated) { _, _ in
            Task { await refreshPreferencesIfAuthenticated() }
            refreshActiveWorkoutWidget()
        }
        .onChange(of: deepLinkCoordinator.pendingWorkoutRoute) { _, route in
            guard route != nil else { return }
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .activeSessionBackupDidChange)) { _ in
            refreshActiveWorkoutWidget()
        }
        .onReceive(NotificationCenter.default.publisher(for: .workoutSessionScreenVisibilityDidChange)) { notification in
            activeWorkoutWidget.setWorkoutSessionVisible(
                notification.userInfo?[WorkoutSessionVisibilityNotification.isVisibleKey] as? Bool ?? false
            )
            refreshActiveWorkoutWidget()
        }
        .onOpenURL { url in
            deepLinkCoordinator.handle(url)
        }
        .confirmationDialog(
            "active_workout.stop.confirmation.title",
            isPresented: $isShowingActiveWorkoutStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("active_workout.stop.confirm", role: .destructive) {
                Task { await activeWorkoutWidget.stopAndSuppressCurrentSession() }
            }

            Button("active_workout.stop.cancel", role: .cancel) {}
        } message: {
            Text("active_workout.stop.confirmation.message")
        }
    }

    private func refreshPreferencesIfAuthenticated() async {
        guard auth.isAuthenticated else {
            appPreferences.reset()
            return
        }
        await appPreferences.refresh()
    }

    private func refreshActiveWorkoutWidget() {
        guard auth.isAuthenticated else {
            activeWorkoutWidget.clear()
            return
        }
        activeWorkoutWidget.refresh()
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
