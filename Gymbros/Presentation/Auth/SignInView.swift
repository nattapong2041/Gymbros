import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @State private var viewModel: SignInViewModel
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric private var iconSize: CGFloat = 60
    @ScaledMetric private var buttonHeight: CGFloat = 56

    @MainActor
    init(viewModel: SignInViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? SignInViewModel())
    }

    private var isBusy: Bool { viewModel.pendingProvider != nil }

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
                appleButton
                    .overlay(alignment: .bottom) { lastUsedCaption(for: .apple) }

                if viewModel.isGoogleSignInAvailable {
                    googleButton
                        .overlay(alignment: .bottom) { lastUsedCaption(for: .google) }
                }

                Text("auth.signIn.sameMethodHint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

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

    // MARK: - Apple

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            viewModel.prepareAppleSignIn(request)
        } onCompletion: { result in
            Task { @MainActor in await viewModel.handleAppleSignIn(result) }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: buttonHeight)
        .disabled(isBusy)
        .opacity(isBusy && viewModel.pendingProvider != .apple ? 0.4 : 1)
        .overlay {
            if viewModel.pendingProvider == .apple {
                ProgressView().tint(colorScheme == .dark ? .black : .white)
            }
        }
    }

    // MARK: - Google

    private var googleButton: some View {
        Button {
            Task { await viewModel.signInWithGoogle() }
        } label: {
            ZStack {
                if viewModel.pendingProvider == .google {
                    ProgressView()
                } else {
                    HStack(spacing: 12) {
                        Image("GoogleG")
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .accessibilityHidden(true)
                        Text("auth.signIn.google")
                            .font(.headline)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .foregroundStyle(.primary)
            .background(googleFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(googleBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy && viewModel.pendingProvider != .google ? 0.4 : 1)
        .accessibilityLabel(Text("accessibility.auth.signInWithGoogle"))
    }

    private var googleFill: Color {
        colorScheme == .dark ? Color(red: 0.075, green: 0.075, blue: 0.078) : .white
    }

    private var googleBorder: Color {
        colorScheme == .dark
            ? Color(red: 0.557, green: 0.569, blue: 0.561)
            : Color(red: 0.455, green: 0.463, blue: 0.459)
    }

    // MARK: - Last-used caption

    @ViewBuilder
    private func lastUsedCaption(for provider: AuthProvider) -> some View {
        if viewModel.lastUsedProvider == provider, !isBusy {
            Text("auth.signIn.lastUsed")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .background(Color(.systemBackground))
                .offset(y: 10)
        }
    }
}

#if DEBUG
@MainActor
private final class PreviewLastUsedStore: LastUsedAuthProviderStoring {
    private(set) var lastUsed: AuthProvider?
    init(_ provider: AuthProvider?) { lastUsed = provider }
    func record(_ provider: AuthProvider) { lastUsed = provider }
}

#Preview("Idle") {
    SignInView()
}

#Preview("Error") {
    SignInView(viewModel: {
        let vm = SignInViewModel()
        vm.state = .error(.auth(.credentialMissing))
        return vm
    }())
}

#Preview("Last used Google") {
    SignInView(viewModel: SignInViewModel(lastUsedStore: PreviewLastUsedStore(.google)))
}
#endif
