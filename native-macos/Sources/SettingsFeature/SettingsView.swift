import SwiftUI
import SharedDomain

public struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        let strings = SettingsStrings(language: viewModel.selectedLanguage)

        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(strings.turnRelayTitle)
                    .font(.headline)
                Text(strings.turnRelaySubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                SettingsFieldRow(
                    title: strings.languageTitle,
                    prompt: strings.languagePrompt
                ) {
                    Picker(strings.languageTitle, selection: $viewModel.selectedLanguage) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text("\(language.nativeDisplayName) · \(language.displayName)")
                                .tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                SettingsFieldRow(
                    title: strings.serverURLTitle,
                    prompt: strings.serverURLPrompt
                ) {
                    TextField(strings.serverURLPlaceholder, text: $viewModel.serverURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                }

                SettingsFieldRow(
                    title: strings.usernameTitle,
                    prompt: strings.usernamePrompt
                ) {
                    TextField(strings.usernamePlaceholder, text: $viewModel.serverUsername)
                        .textFieldStyle(.roundedBorder)
                }

                SettingsFieldRow(
                    title: strings.credentialTitle,
                    prompt: strings.credentialPrompt
                ) {
                    SecureField(strings.credentialPlaceholder, text: $viewModel.serverCredential)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )

            HStack(spacing: 12) {
                Button(strings.saveSettings) {
                    try? viewModel.save()
                }
                .buttonStyle(.borderedProminent)

                Button(strings.resetToDefaults) {
                    try? viewModel.reset()
                }
                .buttonStyle(.bordered)

                Spacer()

                if let toastMessage = viewModel.toastMessage {
                    Label(toastMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .task {
            try? viewModel.load()
        }
    }
}

private struct SettingsStrings {
    let language: AppLanguage

    var turnRelayTitle: String {
        language == .english ? "TURN Relay" : "TURN 中继"
    }

    var turnRelaySubtitle: String {
        language == .english
        ? "These values already persist through the typed settings store and are ready to be wired into real transport configuration."
        : "这些设置已经通过强类型存储持久化，可以直接接入真实传输配置。"
    }

    var languageTitle: String {
        language == .english ? "Language" : "语言"
    }

    var languagePrompt: String {
        language == .english ? "Switch the preview shell between English and Chinese." : "在英文和中文之间切换预览界面。"
    }

    var serverURLTitle: String {
        language == .english ? "Server URL" : "服务器地址"
    }

    var serverURLPrompt: String {
        language == .english ? "turn:relay.example.com" : "例如 turn:relay.example.com"
    }

    var serverURLPlaceholder: String {
        "turn:relay.example.com"
    }

    var usernameTitle: String {
        language == .english ? "Username" : "用户名"
    }

    var usernamePrompt: String {
        language == .english ? "Optional credential username" : "可选的认证用户名"
    }

    var usernamePlaceholder: String {
        language == .english ? "Username" : "用户名"
    }

    var credentialTitle: String {
        language == .english ? "Credential" : "凭据"
    }

    var credentialPrompt: String {
        language == .english ? "Optional shared secret" : "可选的共享密钥"
    }

    var credentialPlaceholder: String {
        language == .english ? "Credential" : "凭据"
    }

    var saveSettings: String {
        language == .english ? "Save Settings" : "保存设置"
    }

    var resetToDefaults: String {
        language == .english ? "Reset To Defaults" : "恢复默认"
    }
}

private struct SettingsFieldRow<Content: View>: View {
    let title: String
    let prompt: String
    @ViewBuilder let content: Content

    init(
        title: String,
        prompt: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.prompt = prompt
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            content

            Text(prompt)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
