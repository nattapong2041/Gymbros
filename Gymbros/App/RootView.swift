import SwiftUI

struct RootView: View {
    @State private var auth = AuthService.shared

    var body: some View {
        if auth.isAuthenticated {
            Text("Logged in - Sprint 4 adds TodayView here")
                .foregroundStyle(.secondary)
        } else {
            SignInView()
        }
    }
}

#Preview {
    RootView()
}
