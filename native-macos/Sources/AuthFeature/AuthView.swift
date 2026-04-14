import SharedDomain
import SwiftUI

public struct AuthView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AuthViewModel
    private let language: AppLanguage
    private let onSignedIn: (() -> Void)?

    public init(
        viewModel: AuthViewModel,
        language: AppLanguage = .english,
        onSignedIn: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.language = language
        self.onSignedIn = onSignedIn
    }

    public var body: some View {
        let strings = AuthStrings(language: language)

        VStack(alignment: .leading, spacing: 12) {
            Text(strings.title)
                .font(.title2.bold())

            Text(viewModel.state.authState.isSignedIn ? strings.signedIn : strings.signedOut)
                .foregroundStyle(viewModel.state.authState.isSignedIn ? .green : .secondary)

            if let gamertag = viewModel.state.authState.userProfile?.gamertag, gamertag.isEmpty == false {
                Text("\(strings.gamertag): \(gamertag)")
            }

            if let statusMessage = viewModel.state.authState.statusMessage {
                Text(statusMessage)
                    .foregroundStyle(.secondary)
            }

            if let challenge = viewModel.state.deviceCodeChallenge {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(strings.deviceCode): \(challenge.userCode)")
                        .font(.headline.monospaced())
                    Text("\(strings.verificationURL): \(challenge.verificationURL)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if let errorMessage = viewModel.state.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 10) {
                if viewModel.state.authState.isSignedIn {
                    Button(strings.signOut) {
                        Task {
                            await viewModel.signOut()
                        }
                    }
                    .buttonStyle(.bordered)
                } else if viewModel.state.deviceCodeChallenge == nil {
                    Button(strings.startSignIn) {
                        Task {
                            await viewModel.beginInteractiveSignIn()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(strings.completeSignIn) {
                        Task {
                            await viewModel.completeInteractiveSignIn()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button(strings.close) {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .onChange(of: viewModel.state.authState.isSignedIn) { _, isSignedIn in
            guard isSignedIn else { return }
            onSignedIn?()
            dismiss()
        }
    }
}

private struct AuthStrings {
    let language: AppLanguage

    var title: String { language == .english ? "Authentication" : "登录" }
    var signedIn: String { language == .english ? "Signed in" : "已登录" }
    var signedOut: String { language == .english ? "Signed out" : "未登录" }
    var gamertag: String { language == .english ? "Gamertag" : "玩家名称" }
    var deviceCode: String { language == .english ? "Device code" : "设备码" }
    var verificationURL: String { language == .english ? "Open" : "打开" }
    var startSignIn: String { language == .english ? "Start Sign-In" : "开始登录" }
    var completeSignIn: String { language == .english ? "Complete Sign-In" : "完成登录" }
    var signOut: String { language == .english ? "Sign Out" : "退出登录" }
    var close: String { language == .english ? "Close" : "关闭" }
}
