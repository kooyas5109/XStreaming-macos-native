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
                Text(strings.preferencesTitle)
                    .font(.headline)
                Text(strings.preferencesSubtitle)
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
                    title: strings.gameLanguageTitle,
                    prompt: strings.gameLanguagePrompt
                ) {
                    Picker(strings.gameLanguageTitle, selection: $viewModel.preferredGameLanguage) {
                        Text(strings.gameLanguageEnglish)
                            .tag("en-US")
                        Text(strings.gameLanguageChinese)
                            .tag("zh-CN")
                    }
                    .pickerStyle(.segmented)
                }

                SettingsFieldRow(
                    title: strings.displayModeTitle,
                    prompt: strings.displayModePrompt
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(strings.fullscreenTitle, isOn: $viewModel.launchesFullscreen)
                        Toggle(strings.performanceStyleTitle, isOn: $viewModel.performanceStyleEnabled)
                    }
                    .toggleStyle(.switch)
                }

                SettingsFieldRow(
                    title: strings.streamingTitle,
                    prompt: strings.streamingPrompt
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker(strings.resolutionTitle, selection: $viewModel.resolution) {
                            Text("720p").tag(720)
                            Text("1080p").tag(1080)
                            Text("1080p HQ").tag(1081)
                        }
                        .pickerStyle(.segmented)

                        Picker(strings.videoFormatTitle, selection: $viewModel.videoFormat) {
                            Text(strings.videoFormatAspectRatio).tag("")
                            Text("Stretch").tag("Stretch")
                            Text("Zoom").tag("Zoom")
                            Text("16:10").tag("16:10")
                            Text("18:9").tag("18:9")
                            Text("21:9").tag("21:9")
                            Text("4:3").tag("4:3")
                        }
                        .pickerStyle(.menu)

                        SettingsSliderRow(
                            title: strings.hostBitrateTitle,
                            value: $viewModel.hostBitrate,
                            range: 5...50,
                            step: 1,
                            suffix: "Mb/s"
                        )

                        SettingsSliderRow(
                            title: strings.cloudBitrateTitle,
                            value: $viewModel.cloudBitrate,
                            range: 5...50,
                            step: 1,
                            suffix: "Mb/s"
                        )

                        SettingsSliderRow(
                            title: strings.audioBitrateTitle,
                            value: $viewModel.audioBitrate,
                            range: 5...40,
                            step: 1,
                            suffix: "Kb/s"
                        )
                    }
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

    var preferencesTitle: String {
        language == .english ? "Demo Preferences" : "演示偏好"
    }

    var preferencesSubtitle: String {
        language == .english
        ? "These controls persist through the typed settings store and already shape how the native preview shell behaves."
        : "这些控件会通过强类型设置存储持久化，并且已经会影响当前原生预览壳层的行为。"
    }

    var languageTitle: String {
        language == .english ? "Language" : "语言"
    }

    var languagePrompt: String {
        language == .english ? "Switch the preview shell between English and Chinese." : "在英文和中文之间切换预览界面。"
    }

    var gameLanguageTitle: String {
        language == .english ? "Game Content Language" : "游戏内容语言"
    }

    var gameLanguagePrompt: String {
        language == .english ? "Set the preferred catalog and playback language for future service wiring." : "为后续真实服务接入预设目录和播放语言。"
    }

    var gameLanguageEnglish: String {
        language == .english ? "English" : "英文"
    }

    var gameLanguageChinese: String {
        language == .english ? "Chinese" : "中文"
    }

    var displayModeTitle: String {
        language == .english ? "Display & Feel" : "显示与体验"
    }

    var displayModePrompt: String {
        language == .english ? "Shape the window behavior and the performance-leaning demo profile." : "调整窗口行为和偏性能的演示模式。"
    }

    var fullscreenTitle: String {
        language == .english ? "Launch stream in fullscreen" : "以全屏方式启动串流"
    }

    var performanceStyleTitle: String {
        language == .english ? "Prefer performance style" : "优先使用性能模式"
    }

    var streamingTitle: String {
        language == .english ? "Streaming Tuning" : "串流调节"
    }

    var streamingPrompt: String {
        language == .english
        ? "Mirror the highest-impact tuning controls from the original app."
        : "承接原项目里对观感影响最大的串流调节项。"
    }

    var resolutionTitle: String {
        language == .english ? "Resolution" : "分辨率"
    }

    var videoFormatTitle: String {
        language == .english ? "Video Format" : "画面比例"
    }

    var videoFormatAspectRatio: String {
        language == .english ? "Aspect ratio" : "保持比例"
    }

    var hostBitrateTitle: String {
        language == .english ? "Host Bitrate" : "主机码率"
    }

    var cloudBitrateTitle: String {
        language == .english ? "Cloud Bitrate" : "云端码率"
    }

    var audioBitrateTitle: String {
        language == .english ? "Audio Bitrate" : "音频码率"
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

private struct SettingsSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title): \(Int(value.rounded())) \(suffix)")
                .font(.subheadline.weight(.semibold))

            Slider(value: $value, in: range, step: step)
        }
    }
}
