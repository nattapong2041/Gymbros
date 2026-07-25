import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @State private var viewModel: SignInViewModel
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric private var iconSize: CGFloat = 60

    @MainActor
    init(viewModel: SignInViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? SignInViewModel())
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.brandSparkLime, .brandHeroViolet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .accessibilityHidden(true)

                Text("GymBros")
                    .font(.largeTitle.bold())

                Text("auth.signIn.tagline")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    viewModel.prepareAppleSignIn(request)
                } onCompletion: { result in
                    Task { @MainActor in await viewModel.handleAppleSignIn(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 56)

                if case .error(let error) = viewModel.state, error.isVisibleToUser {
                    Text(LocalizedStringKey(error.messageKey))
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
    }
}

#Preview("Idle") {
    SignInView()
}

#Preview("Loading") {
    SignInView(viewModel: {
        let vm = SignInViewModel()
        vm.state = .loading
        return vm
    }())
}

#Preview("Error") {
    SignInView(viewModel: {
        let vm = SignInViewModel()
        vm.state = .error(.auth(.appleCredentialMissing))
        return vm
    }())
}

