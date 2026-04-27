import AppKit
import SwiftUI
import SharedDomain
import SupportKit

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
                    title: strings.inputTitle,
                    prompt: strings.inputPrompt
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker(strings.codecTitle, selection: $viewModel.codec) {
                            Text(strings.codecAuto).tag("")
                            Text("H264 High").tag("video/H264-4d")
                            Text("H264 Medium").tag("video/H264-42e")
                            Text("H264 Low").tag("video/H264-420")
                        }
                        .pickerStyle(.segmented)

                        Toggle(strings.nativeMouseKeyboardTitle, isOn: $viewModel.nativeMouseKeyboardEnabled)
                            .toggleStyle(.switch)

                        Toggle(strings.emulatedMouseKeyboardTitle, isOn: $viewModel.mouseKeyboardEnabled)
                            .toggleStyle(.switch)

                        Picker(strings.mouseKeyboardProfileTitle, selection: $viewModel.selectedMouseKeyboardProfileID) {
                            ForEach(viewModel.mouseKeyboardProfiles.profiles) { profile in
                                Text(profile.name).tag(profile.id)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker(strings.mouseMapTargetTitle, selection: $viewModel.mouseKeyboardMouseTarget) {
                            Text(strings.mouseMapOff).tag(MouseKeyboardMouseTarget.off)
                            Text(strings.mouseMapLeftStick).tag(MouseKeyboardMouseTarget.leftStick)
                            Text(strings.mouseMapRightStick).tag(MouseKeyboardMouseTarget.rightStick)
                        }
                        .pickerStyle(.segmented)

                        SettingsSliderRow(
                            title: strings.mouseSensitivityXTitle,
                            value: $viewModel.mouseKeyboardSensitivityX,
                            range: 1...300,
                            step: 1,
                            suffix: "%"
                        )

                        SettingsSliderRow(
                            title: strings.mouseSensitivityYTitle,
                            value: $viewModel.mouseKeyboardSensitivityY,
                            range: 1...300,
                            step: 1,
                            suffix: "%"
                        )

                        SettingsSliderRow(
                            title: strings.mouseDeadzoneCounterweightTitle,
                            value: $viewModel.mouseKeyboardDeadzoneCounterweight,
                            range: 0...100,
                            step: 1,
                            suffix: "%"
                        )

                        mouseKeyboardBindingsEditor(strings: strings)

                        Toggle(strings.vibrationTitle, isOn: $viewModel.vibrationEnabled)
                            .toggleStyle(.switch)

                        SettingsSliderRow(
                            title: strings.mouseSensitivityTitle,
                            value: $viewModel.mouseSensitivity,
                            range: 0.1...5,
                            step: 0.1,
                            suffix: "x"
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
        .onChange(of: viewModel.selectedMouseKeyboardProfileID) { _, profileID in
            viewModel.selectMouseKeyboardProfile(profileID)
        }
    }

    @ViewBuilder
    private func mouseKeyboardBindingsEditor(strings: SettingsStrings) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(strings.mouseBindingsTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(strings.mouseBindingsPrompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(strings.newProfileAction) {
                    viewModel.createProfile()
                }
                .buttonStyle(.bordered)

                Button(strings.duplicateProfileAction) {
                    viewModel.duplicateSelectedProfile()
                }
                .buttonStyle(.bordered)

                Button(strings.importProfileAction) {
                    importMouseKeyboardProfile()
                }
                .buttonStyle(.bordered)

                Button(strings.exportProfileAction) {
                    exportMouseKeyboardProfile()
                }
                .buttonStyle(.bordered)

                Button(strings.deleteProfileAction) {
                    viewModel.deleteSelectedProfile()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.selectedMouseKeyboardProfile.isBuiltIn)
            }

            Picker(strings.mouseKeyboardProfileTitle, selection: $viewModel.selectedMouseKeyboardProfileID) {
                ForEach(viewModel.mouseKeyboardProfiles.profiles) { profile in
                    Text(profile.name).tag(profile.id)
                }
            }
            .pickerStyle(.menu)

            TextField(
                strings.profileNamePlaceholder,
                text: Binding(
                    get: { viewModel.selectedMouseKeyboardProfile.name },
                    set: { viewModel.updateSelectedProfileName($0) }
                )
            )
            .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(strings.actionColumnTitle)
                        .frame(width: 140, alignment: .leading)
                    Text(strings.primaryBindingTitle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(strings.secondaryBindingTitle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                ForEach(MouseKeyboardProfiles.controlOrder, id: \.self) { control in
                    HStack(spacing: 8) {
                        Text(strings.label(for: control))
                            .frame(width: 140, alignment: .leading)

                        MouseKeyboardBindingCaptureButton(
                            title: viewModel.binding(for: control, slot: 0).map(WebInputCodeMapper.displayName(for:)) ?? strings.unboundBinding,
                            prompt: strings.pressKeyPrompt,
                            clearTitle: strings.clearBindingAction
                        ) { code in
                            viewModel.setBinding(code, for: control, slot: 0)
                        } onClear: {
                            viewModel.setBinding(nil, for: control, slot: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        MouseKeyboardBindingCaptureButton(
                            title: viewModel.binding(for: control, slot: 1).map(WebInputCodeMapper.displayName(for:)) ?? strings.unboundBinding,
                            prompt: strings.pressKeyPrompt,
                            clearTitle: strings.clearBindingAction
                        ) { code in
                            viewModel.setBinding(code, for: control, slot: 1)
                        } onClear: {
                            viewModel.setBinding(nil, for: control, slot: 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func importMouseKeyboardProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = viewModel.selectedLanguage == .english ? "Import Mouse & Keyboard Profile" : "导入键鼠配置"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        try? viewModel.importMouseKeyboardProfile(from: url)
    }

    private func exportMouseKeyboardProfile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(viewModel.selectedMouseKeyboardProfile.name).json"
        panel.title = viewModel.selectedLanguage == .english ? "Export Mouse & Keyboard Profile" : "导出键鼠配置"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        try? viewModel.exportSelectedProfile(to: url)
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

    var inputTitle: String {
        language == .english ? "Input & Playback" : "输入与播放"
    }

    var inputPrompt: String {
        language == .english
        ? "Carry over codec, mouse, and rumble controls from the original app."
        : "承接原项目里的 codec、键鼠和震动相关控制。"
    }

    var codecTitle: String {
        language == .english ? "Codec" : "编码格式"
    }

    var codecAuto: String {
        language == .english ? "Auto" : "自动"
    }

    var nativeMouseKeyboardTitle: String {
        language == .english ? "Enable native mouse & keyboard" : "启用原生键鼠"
    }

    var emulatedMouseKeyboardTitle: String {
        language == .english ? "Emulate controller with mouse & keyboard" : "用鼠标和键盘模拟手柄"
    }

    var mouseKeyboardProfileTitle: String {
        language == .english ? "Mouse & keyboard profile" : "键鼠配置文件"
    }

    var mouseMapTargetTitle: String {
        language == .english ? "Map mouse movement to" : "鼠标移动映射到"
    }

    var mouseMapOff: String {
        language == .english ? "Off" : "关闭"
    }

    var mouseMapLeftStick: String {
        language == .english ? "Left Stick" : "左摇杆"
    }

    var mouseMapRightStick: String {
        language == .english ? "Right Stick" : "右摇杆"
    }

    var mouseSensitivityXTitle: String {
        language == .english ? "Mouse sensitivity X" : "鼠标横向灵敏度"
    }

    var mouseSensitivityYTitle: String {
        language == .english ? "Mouse sensitivity Y" : "鼠标纵向灵敏度"
    }

    var mouseDeadzoneCounterweightTitle: String {
        language == .english ? "Mouse deadzone counterweight" : "鼠标死区补偿"
    }

    var mouseBindingsTitle: String {
        language == .english ? "Controller Bindings" : "手柄映射"
    }

    var mouseBindingsPrompt: String {
        language == .english
        ? "Click a slot, then press a key, mouse button, or wheel direction. Use the context menu to clear a binding."
        : "点击槽位后按下键盘、鼠标按键或滚轮方向即可绑定；通过右键菜单可以清空绑定。"
    }

    var newProfileAction: String {
        language == .english ? "New" : "新建"
    }

    var duplicateProfileAction: String {
        language == .english ? "Duplicate" : "复制"
    }

    var deleteProfileAction: String {
        language == .english ? "Delete" : "删除"
    }

    var importProfileAction: String {
        language == .english ? "Import JSON" : "导入 JSON"
    }

    var exportProfileAction: String {
        language == .english ? "Export JSON" : "导出 JSON"
    }

    var profileNamePlaceholder: String {
        language == .english ? "Profile name" : "配置名称"
    }

    var actionColumnTitle: String {
        language == .english ? "Action" : "动作"
    }

    var primaryBindingTitle: String {
        language == .english ? "Primary" : "主绑定"
    }

    var secondaryBindingTitle: String {
        language == .english ? "Secondary" : "副绑定"
    }

    var unboundBinding: String {
        language == .english ? "Unbound" : "未绑定"
    }

    var pressKeyPrompt: String {
        language == .english ? "Press a key or mouse input" : "按下键盘或鼠标输入"
    }

    var clearBindingAction: String {
        language == .english ? "Clear" : "清空"
    }

    func label(for control: MouseKeyboardGamepadControl) -> String {
        switch control {
        case .buttonA: return language == .english ? "A" : "A"
        case .buttonB: return language == .english ? "B" : "B"
        case .buttonX: return language == .english ? "X" : "X"
        case .buttonY: return language == .english ? "Y" : "Y"
        case .leftShoulder: return language == .english ? "LB" : "LB"
        case .rightShoulder: return language == .english ? "RB" : "RB"
        case .leftTrigger: return language == .english ? "LT" : "LT"
        case .rightTrigger: return language == .english ? "RT" : "RT"
        case .view: return language == .english ? "View" : "视图"
        case .menu: return language == .english ? "Menu" : "菜单"
        case .leftThumbPress: return language == .english ? "L3" : "左摇杆按压"
        case .rightThumbPress: return language == .english ? "R3" : "右摇杆按压"
        case .dpadUp: return language == .english ? "D-Pad Up" : "方向键上"
        case .dpadDown: return language == .english ? "D-Pad Down" : "方向键下"
        case .dpadLeft: return language == .english ? "D-Pad Left" : "方向键左"
        case .dpadRight: return language == .english ? "D-Pad Right" : "方向键右"
        case .nexus: return language == .english ? "Nexus" : "Xbox 键"
        case .share: return language == .english ? "Share" : "分享"
        case .leftStickUp: return language == .english ? "Left Stick Up" : "左摇杆上"
        case .leftStickDown: return language == .english ? "Left Stick Down" : "左摇杆下"
        case .leftStickLeft: return language == .english ? "Left Stick Left" : "左摇杆左"
        case .leftStickRight: return language == .english ? "Left Stick Right" : "左摇杆右"
        case .rightStickUp: return language == .english ? "Right Stick Up" : "右摇杆上"
        case .rightStickDown: return language == .english ? "Right Stick Down" : "右摇杆下"
        case .rightStickLeft: return language == .english ? "Right Stick Left" : "右摇杆左"
        case .rightStickRight: return language == .english ? "Right Stick Right" : "右摇杆右"
        }
    }

    var vibrationTitle: String {
        language == .english ? "Enable vibration" : "启用震动"
    }

    var mouseSensitivityTitle: String {
        language == .english ? "Mouse sensitivity" : "鼠标灵敏度"
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

private struct MouseKeyboardBindingCaptureButton: View {
    let title: String
    let prompt: String
    let clearTitle: String
    let onBind: (String) -> Void
    let onClear: () -> Void

    @State private var isCapturing = false
    @State private var monitors: [Any] = []

    var body: some View {
        Button(isCapturing ? prompt : title) {
            beginCapture()
        }
        .buttonStyle(.bordered)
        .contextMenu {
            Button(clearTitle) {
                stopCapture()
                onClear()
            }
        }
        .onDisappear {
            stopCapture()
        }
    }

    private func beginCapture() {
        stopCapture()
        isCapturing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard isCapturing else {
                return
            }

            let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {
                    stopCapture()
                    return nil
                }
                guard let code = WebInputCodeMapper.code(for: event) else {
                    return event
                }
                onBind(code)
                stopCapture()
                return nil
            }

            let leftClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
                onBind(WebInputCodeMapper.mouseButtonCode(for: event))
                stopCapture()
                return nil
            }

            let rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp) { event in
                onBind(WebInputCodeMapper.mouseButtonCode(for: event))
                stopCapture()
                return nil
            }

            let otherClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseUp) { event in
                onBind(WebInputCodeMapper.mouseButtonCode(for: event))
                stopCapture()
                return nil
            }

            let wheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                guard let code = WebInputCodeMapper.wheelCode(
                    vertical: Double(event.scrollingDeltaY),
                    horizontal: Double(event.scrollingDeltaX)
                ) else {
                    return event
                }
                onBind(code)
                stopCapture()
                return nil
            }

            monitors = [keyMonitor, leftClickMonitor, rightClickMonitor, otherClickMonitor, wheelMonitor].compactMap { $0 }
        }
    }

    private func stopCapture() {
        isCapturing = false
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }
}
