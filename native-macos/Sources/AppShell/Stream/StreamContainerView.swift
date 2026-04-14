import SharedDomain
import StreamingFeature
import SwiftUI

public struct StreamContainerView: View {
    public let route: AppRouter.Route

    private let streamingService: StreamingService
    private let engine: any StreamingEngineProtocol
    private let router: AppRouter
    @State private var state: StreamingStateMachine.State = .idle
    @State private var isStarting = false
    @State private var isStopping = false
    @State private var errorMessage: String?

    public init(
        route: AppRouter.Route,
        streamingService: StreamingService,
        engine: any StreamingEngineProtocol,
        router: AppRouter
    ) {
        self.route = route
        self.streamingService = streamingService
        self.engine = engine
        self.router = router
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    ShellSectionHeader(
                        eyebrow: routeEyebrow,
                        title: title,
                        subtitle: "This is the staged native stream shell. It renders a native preview surface and drives typed session state."
                    )

                    Spacer()

                    VStack(alignment: .trailing, spacing: 10) {
                        Button {
                            router.route(to: backRoute)
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }

                        ShellStatusBadge(label: stateLabel, tint: stateTint)
                    }
                }

                HStack(spacing: 14) {
                    ShellMetricCard(
                        title: "Engine",
                        value: engine.capabilities.supportsRumble ? "Native" : "Compatibility",
                        icon: "sparkles.tv",
                        tint: .cyan
                    )
                    ShellMetricCard(
                        title: "Video",
                        value: engine.capabilities.supportsVideo ? "Enabled" : "Unavailable",
                        icon: "video.fill",
                        tint: .blue
                    )
                    ShellMetricCard(
                        title: "Rumble",
                        value: engine.capabilities.supportsRumble ? "Ready" : "Pending",
                        icon: "waveform.path.ecg.rectangle",
                        tint: .green
                    )
                }

                ShellPanel(
                    title: "Stream Surface",
                    subtitle: "Run the staged playback flow and observe route, state, and renderer changes in one place."
                ) {
                    HStack(spacing: 12) {
                        Button(startButtonTitle) {
                            Task {
                                await startStream()
                            }
                        }
                        .disabled(isStarting || isStopping)

                        Button("Stop Stream") {
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
        switch route {
        case .streamConsole(let id):
            return "Console Stream \(id)"
        case .streamCloud(let id):
            return "Cloud Stream \(id)"
        case .home, .cloud, .settings:
            return "Stream"
        }
    }

    private var stateLabel: String {
        switch state {
        case .idle:
            return "Idle"
        case .pending:
            return "Pending"
        case .queued:
            return "Queued"
        case .readyToConnect:
            return "Ready"
        case .connecting:
            return "Connecting"
        case .streaming:
            return "Streaming"
        case .stopped:
            return "Stopped"
        case .failed:
            return "Failed"
        }
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

    private var routeEyebrow: String {
        switch route {
        case .streamConsole:
            return "Console Stream"
        case .streamCloud:
            return "Cloud Stream"
        case .home, .cloud, .settings:
            return "Stream"
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
        isStarting ? "Starting..." : "Start Preview Stream"
    }

    private var capabilitiesLabel: String {
        engine.capabilities.supportsRumble ? "Native surface" : "Web view surface"
    }

    @ViewBuilder
    private var streamingSurface: some View {
        if let nativeEngine = engine as? NativeStreamingEngine {
            NativeVideoSurfaceView(renderer: nativeEngine.videoRenderer)
        } else if let webViewEngine = engine as? WebViewStreamingEngine {
            StreamingWebView(engine: webViewEngine)
        } else {
            ContentUnavailableView(
                "No Streaming Surface",
                systemImage: "display.slash",
                description: Text("The selected streaming engine does not expose a render surface yet.")
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
