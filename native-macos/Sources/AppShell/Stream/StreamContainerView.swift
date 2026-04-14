import SharedDomain
import StreamingFeature
import SwiftUI

public struct StreamContainerView: View {
    public let route: AppRouter.Route

    private let streamingService: StreamingService
    private let engine: WebViewStreamingEngine
    @State private var state: StreamingStateMachine.State = .idle
    @State private var isStarting = false
    @State private var errorMessage: String?

    public init(
        route: AppRouter.Route,
        streamingService: StreamingService,
        engine: WebViewStreamingEngine
    ) {
        self.route = route
        self.streamingService = streamingService
        self.engine = engine
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.largeTitle.weight(.semibold))

            HStack(spacing: 12) {
                Text("State: \(stateLabel)")
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Start Stream") {
                    Task {
                        await startStream()
                    }
                }
                .disabled(isStarting)
            }

            StreamingWebView(engine: engine)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .padding()
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
