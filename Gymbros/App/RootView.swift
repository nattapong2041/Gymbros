import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var auth = AuthService.shared

    var body: some View {
        Group {
            if auth.isAuthenticated {
                Text("root.signedIn.placeholder")
                    .foregroundStyle(.secondary)
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

#Preview {
    RootView()
}
