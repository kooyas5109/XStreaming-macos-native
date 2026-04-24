import SharedDomain
import StreamingFeature

public struct ShellStrings {
    public let language: AppLanguage

    public init(language: AppLanguage) {
        self.language = language
    }

    public var appSubtitle: String {
        switch language {
        case .english:
            return "macOS preview"
        case .simplifiedChinese:
            return "macOS 预览版"
        }
    }

    public var previewStackTitle: String {
        switch language {
        case .english:
            return "Stream Status"
        case .simplifiedChinese:
            return "串流状态"
        }
    }

    public var languageBadgeTitle: String {
        switch language {
        case .english:
            return "EN"
        case .simplifiedChinese:
            return "中文"
        }
    }

    public var languageStatusSummary: String {
        switch language {
        case .english:
            return "English UI"
        case .simplifiedChinese:
            return "中文界面"
        }
    }

    public var nativeEngineActive: String {
        switch language {
        case .english:
            return "Ready"
        case .simplifiedChinese:
            return "已就绪"
        }
    }

    public var compatibilityEngineActive: String {
        switch language {
        case .english:
            return "Ready"
        case .simplifiedChinese:
            return "已就绪"
        }
    }

    public var homeTab: String {
        switch language {
        case .english:
            return "Home"
        case .simplifiedChinese:
            return "主页"
        }
    }

    public var cloudTab: String {
        switch language {
        case .english:
            return "Cloud"
        case .simplifiedChinese:
            return "云游戏"
        }
    }

    public var settingsTab: String {
        switch language {
        case .english:
            return "Settings"
        case .simplifiedChinese:
            return "设置"
        }
    }

    public func rootTitle(for route: AppRouter.Route) -> String {
        switch route {
        case .home:
            return language == .english ? "Console Library" : "主机库"
        case .cloud:
            return language == .english ? "Cloud Catalog" : "云游戏目录"
        case .settings:
            return settingsTab
        case .streamConsole:
            return language == .english ? "Console Stream" : "主机串流"
        case .streamCloud:
            return language == .english ? "Cloud Stream" : "云串流"
        }
    }

    public func rootSubtitle(for route: AppRouter.Route) -> String {
        switch route {
        case .home:
            return language == .english ? "Browse your local Xbox devices" : "浏览你的本地 Xbox 设备"
        case .cloud:
            return language == .english ? "Pick a title and jump into preview streaming" : "选择游戏并进入预览串流"
        case .settings:
            return language == .english ? "Adjust playback, TURN, and demo preferences" : "调整播放、TURN 与演示偏好"
        case .streamConsole(let id):
            return language == .english ? "Preview session for console \(id)" : "主机 \(id) 的预览会话"
        case .streamCloud(let id):
            return language == .english ? "Preview session for title \(id)" : "游戏 \(id) 的预览会话"
        }
    }

    public var homeEyebrow: String { homeTab }
    public var homeTitle: String { language == .english ? "Console Library" : "主机库" }
    public var homeSubtitle: String {
        language == .english
        ? "Launch into your local Xbox devices and preview the macOS streaming flow."
        : "从你的本地 Xbox 设备进入，预览 macOS 串流流程。"
    }
    public var availableConsoles: String { language == .english ? "Available Consoles" : "可用主机" }
    public var readyToStream: String { language == .english ? "Ready To Stream" : "可直接串流" }
    public var previewEngine: String { language == .english ? "Stream Preview" : "串流预览" }
    public var nativeLabel: String { language == .english ? "Native" : "原生" }
    public var compatibilityLabel: String { language == .english ? "Compatibility" : "兼容层" }
    public var yourConsoles: String { language == .english ? "Your Consoles" : "你的主机" }
    public var yourConsolesSubtitle: String {
        language == .english
        ? "Choose a device to open the current stream preview."
        : "选择一台设备，打开当前的串流预览界面。"
    }
    public var loadingConsoles: String { language == .english ? "Loading Consoles..." : "正在加载主机..." }
    public var noConsoles: String { language == .english ? "No Consoles" : "没有可用主机" }
    public var noConsolesDescription: String {
        language == .english
        ? "Connect an Xbox to start a console stream."
        : "连接一台 Xbox 后即可开始主机串流。"
    }
    public var openAction: String { language == .english ? "Open" : "打开" }
    public var refreshAction: String { language == .english ? "Refresh" : "刷新" }
    public var retryAction: String { language == .english ? "Retry" : "重试" }

    public var cloudEyebrow: String { cloudTab }
    public var cloudTitle: String { language == .english ? "Cloud Gaming Catalog" : "云游戏目录" }
    public var cloudSubtitle: String {
        language == .english
        ? "Browse a compact Game Pass style catalog and jump into the native preview stream."
        : "浏览精简版 Game Pass 风格目录，并进入原生预览串流。"
    }
    public var visibleTitles: String { language == .english ? "Visible Titles" : "可见游戏" }
    public var recentlyPlayed: String { language == .english ? "Recently Played" : "最近游玩" }
    public var keyboardSupport: String { language == .english ? "Keyboard Support" : "键鼠支持" }
    public var browseTitles: String { language == .english ? "Browse Titles" : "浏览游戏" }
    public var browseTitlesSubtitle: String {
        language == .english
        ? "Switch between recently played, newest arrivals, and the full preview catalog."
        : "在最近游玩、最新加入和完整预览目录之间切换。"
    }
    public var catalogPickerLabel: String { language == .english ? "Catalog" : "目录" }
    public var catalogRecently: String { language == .english ? "Recently" : "最近" }
    public var catalogNewest: String { language == .english ? "Newest" : "最新" }
    public var catalogAll: String { language == .english ? "All" : "全部" }
    public var loadingCatalog: String { language == .english ? "Loading Catalog..." : "正在加载目录..." }
    public var catalogEmptyTitle: String { language == .english ? "No Titles Available" : "当前没有可用游戏" }
    public var catalogEmptyDescription: String {
        language == .english
        ? "Reload the preview catalog or switch tabs after the service comes online."
        : "请在服务可用后重新加载预览目录，或切换不同分类。"
    }

    public var settingsEyebrow: String { settingsTab }
    public var settingsTitle: String { language == .english ? "Streaming Preferences" : "串流偏好" }
    public var settingsSubtitle: String {
        language == .english
        ? "Tune TURN relay details and demo playback options for the native preview shell."
        : "为原生预览壳层调整 TURN 中继和演示播放选项。"
    }
    public var displayMode: String { language == .english ? "Display" : "显示" }
    public var immersive: String { language == .english ? "Immersive" : "沉浸式" }
    public var windowed: String { language == .english ? "Windowed" : "窗口化" }
    public var experience: String { language == .english ? "Experience" : "体验" }
    public var balanced: String { language == .english ? "Balanced" : "平衡" }
    public var performance: String { language == .english ? "Performance" : "性能" }
    public var shellLanguage: String { language == .english ? "Shell Language" : "界面语言" }
    public var gameLanguage: String { language == .english ? "Game Language" : "游戏语言" }
    public var englishLanguage: String { language == .english ? "English" : "英文" }
    public var chineseLanguage: String { language == .english ? "Chinese" : "中文" }
    public var transport: String { language == .english ? "Transport" : "传输" }
    public var transportDefault: String { language == .english ? "Default" : "默认" }
    public var customTurn: String { language == .english ? "Custom TURN" : "自定义 TURN" }
    public var audio: String { language == .english ? "Audio" : "音频" }
    public var managed: String { language == .english ? "Managed" : "托管" }
    public var auto: String { language == .english ? "Auto" : "自动" }
    public var rumble: String { language == .english ? "Rumble" : "震动" }
    public var enabled: String { language == .english ? "Enabled" : "已启用" }
    public var disabled: String { language == .english ? "Disabled" : "已关闭" }
    public var relayPlaybackTitle: String { language == .english ? "Relay And Playback" : "中继与播放" }
    public var relayPlaybackSubtitle: String {
        language == .english
        ? "These controls already write through the typed settings store and are ready for live migration work."
        : "这些控件已经接入强类型设置存储，可直接承接后续真实迁移。"
    }
    public var shellStatusTitle: String { language == .english ? "Shell Status" : "壳层状态" }
    public var shellStatusSubtitle: String {
        language == .english
        ? "Quickly inspect the current interface language, display mode, and preview posture."
        : "快速查看当前界面语言、显示模式和预览状态。"
    }
    public var openSettingsAction: String { language == .english ? "Open Settings" : "打开设置" }

    public func streamTitle(for route: AppRouter.Route) -> String {
        switch route {
        case .streamConsole(let id):
            return language == .english ? "Console Stream \(id)" : "主机串流 \(id)"
        case .streamCloud(let id):
            return language == .english ? "Cloud Stream \(id)" : "云串流 \(id)"
        case .home, .cloud, .settings:
            return language == .english ? "Stream" : "串流"
        }
    }

    public func streamEyebrow(for route: AppRouter.Route) -> String {
        switch route {
        case .streamConsole:
            return language == .english ? "Console Stream" : "主机串流"
        case .streamCloud:
            return language == .english ? "Cloud Stream" : "云串流"
        case .home, .cloud, .settings:
            return language == .english ? "Stream" : "串流"
        }
    }

    public var streamSubtitle: String {
        language == .english
        ? "Connect a real Xbox streaming session through the compatibility WebRTC surface and typed native state."
        : "通过兼容 WebRTC 播放面连接真实 Xbox 串流会话，并驱动类型化原生状态。"
    }
    public var back: String { language == .english ? "Back" : "返回" }
    public var engine: String { language == .english ? "Engine" : "引擎" }
    public var video: String { language == .english ? "Video" : "画面" }
    public var ready: String { language == .english ? "Ready" : "就绪" }
    public var pending: String { language == .english ? "Pending" : "等待中" }
    public var unavailable: String { language == .english ? "Unavailable" : "不可用" }
    public var streamSurfaceTitle: String { language == .english ? "Stream Surface" : "串流画面" }
    public var streamSurfaceSubtitle: String {
        language == .english
        ? "Start live playback and observe session state, signaling, and player negotiation in one place."
        : "启动真实播放，并在同一处观察会话状态、信令和播放器协商。"
    }
    public var startPreviewStream: String { language == .english ? "Start Stream" : "开始串流" }
    public var streamAction: String { language == .english ? "Stream" : "串流" }
    public var starting: String { language == .english ? "Starting..." : "启动中..." }
    public var stopStream: String { language == .english ? "Stop Stream" : "停止串流" }
    public var nativeSurface: String { language == .english ? "Native surface" : "原生画面" }
    public var webViewSurface: String { language == .english ? "Web view surface" : "网页画面" }
    public var noActiveSession: String { language == .english ? "No active session" : "当前没有活动会话" }
    public func sessionLabel(_ id: String) -> String {
        language == .english ? "Session \(id)" : "会话 \(id)"
    }
    public var noStreamingSurface: String { language == .english ? "No Streaming Surface" : "没有可用串流画面" }
    public var noStreamingSurfaceDescription: String {
        language == .english
        ? "The selected streaming engine does not expose a render surface yet."
        : "当前所选串流引擎暂时还没有暴露可渲染画面。"
    }
    public var fullscreenAction: String { language == .english ? "Toggle Fullscreen" : "切换全屏" }
    public var performancePanelTitle: String { language == .english ? "Stream Performance" : "串流性能" }
    public var performancePanelSubtitle: String {
        language == .english
        ? "A staged performance strip inspired by the original app. Layout follows your saved performance style preference."
        : "参考原项目的阶段性性能信息条，并根据你保存的展示样式切换布局。"
    }
    public var resolutionMetric: String { language == .english ? "Resolution" : "分辨率" }
    public var rttMetric: String { language == .english ? "RTT" : "RTT" }
    public var jitMetric: String { language == .english ? "JIT" : "JIT" }
    public var fpsMetric: String { language == .english ? "FPS" : "FPS" }
    public var frameDropsMetric: String { language == .english ? "FD" : "丢帧" }
    public var packetLossMetric: String { language == .english ? "PL" : "丢包" }
    public var bitrateMetric: String { language == .english ? "Bitrate" : "码率" }
    public var decodeMetric: String { language == .english ? "DT" : "解码" }
    public var horizonStyle: String { language == .english ? "Horizontal style" : "横向样式" }
    public var verticalStyle: String { language == .english ? "Vertical style" : "纵向样式" }
    public var fullscreenEnabledHint: String {
        language == .english ? "Fullscreen preference will apply on stream start." : "开始串流时会应用全屏偏好。"
    }
    public var quickControlsTitle: String { language == .english ? "Quick Controls" : "快捷控制" }
    public var quickControlsSubtitle: String {
        language == .english
        ? "A native take on the original action bar: tune display, audio, fullscreen, and overlay visibility in one place."
        : "原项目操作栏的原生化版本：在一处调整显示、音频、全屏和性能覆盖层。"
    }
    public var displaySettingsAction: String { language == .english ? "Display Settings" : "画面设置" }
    public var audioSettingsAction: String { language == .english ? "Audio Settings" : "音频设置" }
    public var togglePerformanceAction: String { language == .english ? "Toggle Performance" : "切换性能信息" }
    public var showPerformanceAction: String { language == .english ? "Show Performance" : "显示性能" }
    public var hidePerformanceAction: String { language == .english ? "Hide Performance" : "隐藏性能" }
    public var openMicAction: String { language == .english ? "Open Mic" : "打开麦克风" }
    public var closeMicAction: String { language == .english ? "Close Mic" : "关闭麦克风" }
    public var disconnectAction: String { language == .english ? "Disconnect" : "断开连接" }
    public var displayPanelTitle: String { language == .english ? "Display" : "显示" }
    public var displayPanelSubtitle: String {
        language == .english
        ? "These staged controls mirror the original app's display tuning model."
        : "这些阶段性控件对应原项目的画面调节模型。"
    }
    public var audioPanelTitle: String { language == .english ? "Audio" : "音频" }
    public var audioPanelSubtitle: String {
        language == .english
        ? "Use a simple native volume control before real transport audio management arrives."
        : "在真实传输层音频管理接入前，先用一个简洁的原生音量控制承接。"
    }
    public var displaySharpness: String { language == .english ? "Sharpness" : "锐度" }
    public var displaySaturation: String { language == .english ? "Saturation" : "饱和度" }
    public var displayContrast: String { language == .english ? "Contrast" : "对比度" }
    public var displayBrightness: String { language == .english ? "Brightness" : "亮度" }
    public var volumeTitle: String { language == .english ? "Volume" : "音量" }
    public var savedAction: String { language == .english ? "Saved" : "已保存" }
    public var disconnectHint: String {
        language == .english ? "Disconnect returns to the previous catalog view." : "断开连接后会返回上一级目录页面。"
    }
    public var sendTextAction: String { language == .english ? "Send Text" : "发送文本" }
    public var pressNexusAction: String { language == .english ? "Press Nexus" : "按下 Nexus" }
    public var longPressNexusAction: String { language == .english ? "Long Press Nexus" : "长按 Nexus" }
    public var disconnectAndPowerOffAction: String { language == .english ? "Disconnect & Power Off" : "断开并关机" }
    public var sendTextTitle: String { language == .english ? "Send text to console" : "发送文本到主机" }
    public var sendTextPrompt: String { language == .english ? "Mirror the original app's in-stream text input with a native dialog." : "用原生弹窗承接旧项目里的串流内文本输入。" }
    public var sendTextPlaceholder: String { language == .english ? "Type a short message" : "输入一段简短文本" }
    public var sendTextConfirm: String { language == .english ? "Send" : "发送" }
    public var sendTextCancel: String { language == .english ? "Cancel" : "取消" }
    public var sendTextSuccess: String { language == .english ? "Text command sent to the connected console." : "文本命令已发送到当前主机。" }
    public var nexusPressSuccess: String { language == .english ? "Sent a Nexus button press." : "已发送一次 Nexus 按键。" }
    public var nexusLongPressSuccess: String { language == .english ? "Sent a long Nexus button press." : "已发送一次长按 Nexus。" }
    public var disconnectPowerOffSuccess: String { language == .english ? "Stream disconnected and power-off command queued." : "串流已断开，并已排队发送关机命令。" }
    public var commandMenuHint: String { language == .english ? "Menu actions are also available from the Stream menu and keyboard shortcuts." : "这些动作也可以通过菜单栏里的“串流”菜单和快捷键触发。" }
    public var codecBadgeTitle: String { language == .english ? "Codec" : "编码" }
    public var nativeMouseKeyboardBadgeTitle: String { language == .english ? "Mouse & Keyboard" : "键鼠" }
    public var vibrationBadgeTitle: String { language == .english ? "Vibration" : "震动" }
    public var bitrateBadgeTitle: String { language == .english ? "Bitrate Plan" : "码率方案" }
    public var accountTitle: String { language == .english ? "Account" : "账户" }
    public var accountSignedIn: String { language == .english ? "Signed In" : "已登录" }
    public var accountSignedOut: String { language == .english ? "Signed Out" : "未登录" }
    public var manageAccountAction: String { language == .english ? "Manage Sign-In" : "管理登录" }
    public var authModeTitle: String { language == .english ? "Auth Mode" : "登录模式" }
    public var authModePreview: String { language == .english ? "Preview" : "预览" }
    public var authModeLive: String { language == .english ? "Live" : "在线" }

    public func streamStateLabel(_ state: StreamingStateMachine.State) -> String {
        switch state {
        case .idle:
            return language == .english ? "Idle" : "空闲"
        case .pending:
            return pending
        case .queued:
            return language == .english ? "Queued" : "排队中"
        case .readyToConnect:
            return ready
        case .connecting:
            return language == .english ? "Connecting" : "连接中"
        case .streaming:
            return language == .english ? "Streaming" : "串流中"
        case .stopped:
            return language == .english ? "Stopped" : "已停止"
        case .failed:
            return language == .english ? "Failed" : "失败"
        }
    }

    public func streamHelpText(for state: StreamingStateMachine.State) -> String {
        switch state {
        case .idle:
            return language == .english ? "Press start to create a streaming session." : "点击开始以创建串流会话。"
        case .pending, .queued:
            return language == .english ? "The streaming session is provisioning." : "串流会话正在准备中。"
        case .readyToConnect, .connecting:
            return language == .english ? "The player is negotiating WebRTC playback." : "播放器正在协商 WebRTC 播放。"
        case .streaming:
            return language == .english ? "Streaming is active." : "串流正在运行。"
        case .stopped:
            return language == .english ? "The streaming session has ended." : "串流会话已结束。"
        case .failed:
            return language == .english ? "Review the error and try again." : "请检查错误信息后重试。"
        }
    }

    public func localizedPowerState(_ state: ConsolePowerState) -> String {
        switch state {
        case .connectedStandby:
            return language == .english ? "Connected standby" : "联网待机"
        case .on:
            return language == .english ? "Online" : "在线"
        case .off:
            return language == .english ? "Offline" : "离线"
        case .unknown:
            return language == .english ? "Unknown" : "未知"
        }
    }

    public func localizedConsoleType(_ type: ConsoleType) -> String {
        switch type {
        case .xboxSeriesX:
            return "Xbox Series X"
        case .xboxSeriesS:
            return "Xbox Series S"
        case .xboxOne:
            return "Xbox One"
        case .xboxOneS:
            return "Xbox One S"
        case .xboxOneX:
            return "Xbox One X"
        case .unknown:
            return language == .english ? "Unknown device" : "未知设备"
        }
    }

    public func localizedInputType(_ type: InputType) -> String {
        switch type {
        case .controller:
            return language == .english ? "Controller" : "手柄"
        case .mouseAndKeyboard:
            return language == .english ? "Mouse + Keyboard" : "键盘 + 鼠标"
        case .touch:
            return language == .english ? "Touch" : "触控"
        case .unknown:
            return language == .english ? "Unknown" : "未知"
        }
    }

    public func localizedPreferredGameLanguage(_ locale: String) -> String {
        if locale.lowercased().hasPrefix("zh") {
            return chineseLanguage
        }
        return englishLanguage
    }

    public func localizedCodec(_ codec: String) -> String {
        switch codec {
        case "video/H264-4d":
            return language == .english ? "H264 High" : "H264 高"
        case "video/H264-42e":
            return language == .english ? "H264 Medium" : "H264 中"
        case "video/H264-420":
            return language == .english ? "H264 Low" : "H264 低"
        default:
            return language == .english ? "Auto" : "自动"
        }
    }
}
