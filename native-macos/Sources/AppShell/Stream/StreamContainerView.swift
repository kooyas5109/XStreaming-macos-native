import PersistenceKit
import SharedDomain
import StreamingFeature
import SwiftUI

public struct StreamContainerView: View {
    public let route: AppRouter.Route

    private let streamingService: StreamingService
    private let engine: any StreamingEngineProtocol
    private let router: AppRouter
    private let settingsStore: SettingsStoreProtocol
    private let language: AppLanguage
    @State private var settings: AppSettings = .defaults
    @State private var performance = StreamPerformanceSnapshot.idle
    @State private var state: StreamingStateMachine.State = .idle
    @State private var isStarting = false
    @State private var isStopping = false
    @State private var errorMessage: String?

    public init(
        route: AppRouter.Route,
        streamingService: StreamingService,
        engine: any StreamingEngineProtocol,
        router: AppRouter,
        settingsStore: SettingsStoreProtocol,
        language: AppLanguage
    ) {
        self.route = route
        self.streamingService = streamingService
        self.engine = engine
        self.router = router
        self.settingsStore = settingsStore
        self.language = language
    }

    public var body: some View {
        let strings = ShellStrings(language: language)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    ShellSectionHeader(
                        eyebrow: strings.streamEyebrow(for: route),
                        title: title,
                        subtitle: strings.streamSubtitle
                    )

                    Spacer()

                    VStack(alignment: .trailing, spacing: 10) {
                        Button {
                            router.route(to: backRoute)
                        } label: {
                            Label(strings.back, systemImage: "chevron.left")
                        }

                        ShellStatusBadge(label: stateLabel, tint: stateTint)
                    }
                }

                HStack(spacing: 14) {
                    ShellMetricCard(
                        title: strings.engine,
                        value: engine.capabilities.supportsRumble ? strings.nativeLabel : strings.compatibilityLabel,
                        icon: "sparkles.tv",
                        tint: .cyan
                    )
                    ShellMetricCard(
                        title: strings.video,
                        value: engine.capabilities.supportsVideo ? strings.enabled : strings.unavailable,
                        icon: "video.fill",
                        tint: .blue
                    )
                    ShellMetricCard(
                        title: strings.rumble,
                        value: engine.capabilities.supportsRumble ? strings.ready : strings.pending,
                        icon: "waveform.path.ecg.rectangle",
                        tint: .green
                    )
                }

                ShellPanel(
                    title: strings.streamSurfaceTitle,
                    subtitle: strings.streamSurfaceSubtitle
                ) {
                    HStack(spacing: 12) {
                        Button(startButtonTitle) {
                            Task {
                                await startStream()
                            }
                        }
                        .disabled(isStarting || isStopping)

                        Button(strings.stopStream) {
                            Task {
                                await stopStream()
                            }
                        }
                        .disabled(state.session == nil || isStarting || isStopping)

                        Button(strings.fullscreenAction) {
                            WindowControls.toggleFullscreen()
                        }
                        .disabled(isStarting)

                        Spacer()

                        ShellStatusBadge(label: capabilitiesLabel, tint: .secondary)
                    }

                    streamingSurface
                        .frame(maxWidth: .infinity, minHeight: 420, maxHeight: 520)
                        .background(.black.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    HStack(spacing: 12) {
                        ShellStatusBadge(label: sessionLabel, tint: .secondary)
                        ShellStatusBadge(label: stateLabel, tint: stateTint)
                        ShellStatusBadge(
                            label: settings.performanceStyle ? strings.horizonStyle : strings.verticalStyle,
                            tint: .secondary
                        )
                        Spacer()
                        Text(helpText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ShellPanel(
                    title: strings.performancePanelTitle,
                    subtitle: strings.performancePanelSubtitle
                ) {
                    if settings.performanceStyle {
                        performanceStrip(strings: strings)
                    } else {
                        performanceGrid(strings: strings)
                    }

                    if settings.fullscreen {
                        Text(strings.fullscreenEnabledHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .padding(28)
        }
        .task {
            loadSettings()
            refreshPerformance(for: state)
        }
        .onChange(of: state) { _, newState in
            refreshPerformance(for: newState)
        }
    }

    private var title: String {
        ShellStrings(language: language).streamTitle(for: route)
    }

    private var stateLabel: String {
        ShellStrings(language: language).streamStateLabel(state)
    }

    private var stateTint: Color {
        switch state {
        case .idle, .stopped:
            return .secondary
        case .pending, .queued, .connecting:
            return .orange
        case .readyToConnect, .streaming:
            return .green
        case .failed:
            return .red
        }
    }

    private var backRoute: AppRouter.Route {
        switch route {
        case .streamConsole:
            return .home
        case .streamCloud:
            return .cloud
        case .home:
            return .home
        case .cloud:
            return .cloud
        case .settings:
            return .settings
        }
    }

    private var startButtonTitle: String {
        let strings = ShellStrings(language: language)
        return isStarting ? strings.starting : strings.startPreviewStream
    }

    private var capabilitiesLabel: String {
        let strings = ShellStrings(language: language)
        return engine.capabilities.supportsRumble ? strings.nativeSurface : strings.webViewSurface
    }

    private var sessionLabel: String {
        let strings = ShellStrings(language: language)
        if let sessionID = state.session?.id {
            return strings.sessionLabel(sessionID)
        }
        return strings.noActiveSession
    }

    private var helpText: String {
        ShellStrings(language: language).streamHelpText(for: state)
    }

    @ViewBuilder
    private func performanceStrip(strings: ShellStrings) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(performanceMetrics(strings: strings), id: \.label) { metric in
                    ShellStatusBadge(label: "\(metric.label): \(metric.value)", tint: .secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func performanceGrid(strings: ShellStrings) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 120), spacing: 12),
                GridItem(.flexible(minimum: 120), spacing: 12),
                GridItem(.flexible(minimum: 120), spacing: 12),
                GridItem(.flexible(minimum: 120), spacing: 12)
            ],
            alignment: .leading,
            spacing: 12
        ) {
            ForEach(performanceMetrics(strings: strings), id: \.label) { metric in
                VStack(alignment: .leading, spacing: 6) {
                    Text(metric.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(metric.value)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }
        }
    }

    private func performanceMetrics(strings: ShellStrings) -> [PerformanceMetric] {
        [
            PerformanceMetric(label: strings.resolutionMetric, value: performance.resolution),
            PerformanceMetric(label: strings.rttMetric, value: performance.rtt),
            PerformanceMetric(label: strings.jitMetric, value: performance.jitter),
            PerformanceMetric(label: strings.fpsMetric, value: performance.fps),
            PerformanceMetric(label: strings.frameDropsMetric, value: performance.frameDrops),
            PerformanceMetric(label: strings.packetLossMetric, value: performance.packetLoss),
            PerformanceMetric(label: strings.bitrateMetric, value: performance.bitrate),
            PerformanceMetric(label: strings.decodeMetric, value: performance.decodeTime)
        ]
    }

    @ViewBuilder
    private var streamingSurface: some View {
        if let nativeEngine = engine as? NativeStreamingEngine {
            NativeVideoSurfaceView(renderer: nativeEngine.videoRenderer)
        } else if let webViewEngine = engine as? WebViewStreamingEngine {
            StreamingWebView(engine: webViewEngine)
        } else {
            let strings = ShellStrings(language: language)
            ContentUnavailableView(
                strings.noStreamingSurface,
                systemImage: "display.slash",
                description: Text(strings.noStreamingSurfaceDescription)
            )
        }
    }

    @MainActor
    private func startStream() async {
        isStarting = true
        errorMessage = nil

        do {
            if settings.fullscreen {
                WindowControls.enterFullscreenIfNeeded()
            }

            let request = streamRequest(for: route)
            state = try await streamingService.startStreaming(
                kind: request.kind,
                targetID: request.targetID
            )
        } catch {
            state = .failed(StreamingErrorDetails(code: "stream_start_failed", message: error.localizedDescription))
            errorMessage = error.localizedDescription
        }

        isStarting = false
    }

    @MainActor
    private func stopStream() async {
        guard let sessionID = state.session?.id else {
            state = .stopped
            return
        }

        isStopping = true
        errorMessage = nil

        do {
            state = try await streamingService.stopStreaming(sessionID: sessionID)
        } catch {
            errorMessage = error.localizedDescription
        }

        isStopping = false
    }

    private func streamRequest(for route: AppRouter.Route) -> (kind: StreamingKind, targetID: String) {
        switch route {
        case .streamConsole(let id):
            return (.home, id)
        case .streamCloud(let id):
            return (.cloud, id)
        case .home, .cloud, .settings:
            return (.cloud, "preview-stream")
        }
    }

    private func loadSettings() {
        settings = (try? settingsStore.load()) ?? .defaults
    }

    private func refreshPerformance(for state: StreamingStateMachine.State? = nil) {
        let activeState = state ?? self.state
        performance = StreamPerformanceSnapshot.preview(
            route: route,
            state: activeState,
            settings: settings,
            nativeEngine: engine.capabilities.supportsRumble
        )
    }
}

private struct PerformanceMetric {
    let label: String
    let value: String
}

private struct StreamPerformanceSnapshot {
    let resolution: String
    let rtt: String
    let jitter: String
    let fps: String
    let frameDrops: String
    let packetLoss: String
    let bitrate: String
    let decodeTime: String

    static let idle = StreamPerformanceSnapshot(
        resolution: "--",
        rtt: "--",
        jitter: "--",
        fps: "--",
        frameDrops: "--",
        packetLoss: "--",
        bitrate: "--",
        decodeTime: "--"
    )

    static func preview(
        route: AppRouter.Route,
        state: StreamingStateMachine.State,
        settings: AppSettings,
        nativeEngine: Bool
    ) -> StreamPerformanceSnapshot {
        let resolution = settings.resolution == 1080 ? "1080p" : "720p"
        let bitrateSeed: Int
        switch route {
        case .streamCloud:
            bitrateSeed = 18
        case .streamConsole:
            bitrateSeed = 24
        case .home, .cloud, .settings:
            bitrateSeed = 18
        }

        switch state {
        case .idle, .stopped:
            return StreamPerformanceSnapshot(
                resolution: resolution,
                rtt: "--",
                jitter: "--",
                fps: "--",
                frameDrops: "--",
                packetLoss: "--",
                bitrate: "--",
                decodeTime: "--"
            )
        case .pending, .queued:
            return StreamPerformanceSnapshot(
                resolution: resolution,
                rtt: "68 ms",
                jitter: "5 ms",
                fps: nativeEngine ? "60" : "30",
                frameDrops: "1",
                packetLoss: "0.2%",
                bitrate: "\(bitrateSeed) Mb/s",
                decodeTime: nativeEngine ? "7 ms" : "10 ms"
            )
        case .readyToConnect, .connecting, .streaming:
            return StreamPerformanceSnapshot(
                resolution: resolution,
                rtt: nativeEngine ? "42 ms" : "58 ms",
                jitter: nativeEngine ? "3 ms" : "6 ms",
                fps: nativeEngine ? "60" : "45",
                frameDrops: nativeEngine ? "0" : "2",
                packetLoss: nativeEngine ? "0.0%" : "0.3%",
                bitrate: "\(bitrateSeed + (settings.performanceStyle ? 6 : 2)) Mb/s",
                decodeTime: nativeEngine ? "5 ms" : "9 ms"
            )
        case .failed:
            return StreamPerformanceSnapshot(
                resolution: resolution,
                rtt: "95 ms",
                jitter: "13 ms",
                fps: "0",
                frameDrops: "8",
                packetLoss: "3.1%",
                bitrate: "0 Mb/s",
                decodeTime: "--"
            )
        }
    }
}
