import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @State private var viewModel = SignInViewModel()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.gymAccent)

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
                    Task { await viewModel.handleAppleSignIn(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if case .error(let error) = viewModel.state, error.isVisibleToUser {
                    Text(LocalizedStringKey(error.messageKey))
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(24)
    }
}

#Preview {
    SignInView()
}
