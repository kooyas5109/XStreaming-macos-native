import AppKit
import SharedDomain
import SwiftUI

public struct AuthView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AuthViewModel
    @State private var copyFeedback: String?
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
        let challenge = viewModel.state.deviceCodeChallenge

        VStack(alignment: .leading, spacing: 12) {
            Text(strings.title)
                .font(.title2.bold())

            Text(viewModel.state.authState.isSignedIn ? strings.signedIn : strings.signedOut)
                .foregroundStyle(viewModel.state.authState.isSignedIn ? .green : .secondary)

            if let gamertag = viewModel.state.authState.userProfile?.gamertag, gamertag.isEmpty == false {
                Text("\(strings.gamertag): \(gamertag)")
            }

            if challenge != nil {
                Text(strings.deviceCodeInstructions)
                    .foregroundStyle(.secondary)
            } else if let statusMessage = viewModel.state.authState.statusMessage {
                Text(statusMessage)
                    .foregroundStyle(.secondary)
            }

            if let challenge {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(strings.deviceCode)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(challenge.userCode)
                                .font(.title3.monospaced().bold())
                                .textSelection(.enabled)
                        }

                        Spacer(minLength: 0)

                        Button(strings.copyCode) {
                            copyToPasteboard(challenge.userCode, feedback: strings.copiedCode)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    HStack(alignment: .center, spacing: 12) {
                        if let verificationURL = URL(string: challenge.verificationURL) {
                            Link(destination: verificationURL) {
                                Label(strings.openVerificationPage, systemImage: "link")
                            }
                            .textSelection(.enabled)
                        } else {
                            Text(challenge.verificationURL)
                                .font(.subheadline)
                                .textSelection(.enabled)
                        }

                        Spacer(minLength: 0)

                        Button(strings.copyLink) {
                            copyToPasteboard(challenge.verificationURL, feedback: strings.copiedLink)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Text(challenge.verificationURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(12)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let errorMessage = viewModel.state.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            if let copyFeedback {
                Label(copyFeedback, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
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

    private func copyToPasteboard(_ value: String, feedback: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copyFeedback = feedback
    }
}

private struct AuthStrings {
    let language: AppLanguage

    var title: String { language == .english ? "Authentication" : "登录" }
    var signedIn: String { language == .english ? "Signed in" : "已登录" }
    var signedOut: String { language == .english ? "Signed out" : "未登录" }
    var gamertag: String { language == .english ? "Gamertag" : "玩家名称" }
    var deviceCode: String { language == .english ? "Device code" : "设备码" }
    var deviceCodeInstructions: String {
        language == .english
            ? "Open the Microsoft verification page, then enter the device code below."
            : "打开 Microsoft 验证页面，然后输入下方设备码完成登录。"
    }
    var openVerificationPage: String { language == .english ? "Open Verification Page" : "打开验证页面" }
    var startSignIn: String { language == .english ? "Start Sign-In" : "开始登录" }
    var completeSignIn: String { language == .english ? "Complete Sign-In" : "完成登录" }
    var signOut: String { language == .english ? "Sign Out" : "退出登录" }
    var close: String { language == .english ? "Close" : "关闭" }
    var copyCode: String { language == .english ? "Copy Code" : "复制代码" }
    var copyLink: String { language == .english ? "Copy Link" : "复制链接" }
    var copiedCode: String { language == .english ? "Device code copied." : "设备码已复制。" }
    var copiedLink: String { language == .english ? "Verification link copied." : "验证链接已复制。" }
}
