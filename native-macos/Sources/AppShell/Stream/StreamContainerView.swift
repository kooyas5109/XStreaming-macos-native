import SharedDomain
import StreamingFeature
import SwiftUI

public struct StreamContainerView: View {
    public let route: AppRouter.Route

    private let streamingService: StreamingService
    private let engine: any StreamingEngineProtocol
    private let router: AppRouter
    private let language: AppLanguage
    @State private var state: StreamingStateMachine.State = .idle
    @State private var isStarting = false
    @State private var isStopping = false
    @State private var errorMessage: String?

    public init(
        route: AppRouter.Route,
        streamingService: StreamingService,
        engine: any StreamingEngineProtocol,
        router: AppRouter,
        language: AppLanguage
    ) {
        self.route = route
        self.streamingService = streamingService
        self.engine = engine
        self.router = router
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
                        Spacer()
                        Text(helpText)
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
}
