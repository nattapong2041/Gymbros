import SwiftUI

struct RootView: View {
    @State private var auth = AuthService.shared

    var body: some View {
        if auth.isAuthenticated {
            Text("root.signedIn.placeholder")
                .foregroundStyle(.secondary)
        } else {
            SignInView()
        }
    }
}

#Preview {
    RootView()
}
