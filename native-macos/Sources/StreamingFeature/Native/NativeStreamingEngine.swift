import Foundation
import SharedDomain

@MainActor
public final class NativeStreamingEngine: StreamingEngineProtocol {
    public let capabilities = StreamingEngineCapabilities(
        supportsVideo: true,
        supportsAudio: true,
        supportsPointerInput: false,
        supportsControllerInput: true,
        supportsNativeOverlay: true,
        supportsRumble: true
    )

    public private(set) var currentSession: StreamingSession?
    public let webRTCSession: WebRTCSession
    public let audioCoordinator: AudioSessionCoordinator
    public let videoRenderer: VideoRenderer

    public init(
        webRTCSession: WebRTCSession = WebRTCSession(),
        audioCoordinator: AudioSessionCoordinator = AudioSessionCoordinator(),
        videoRenderer: VideoRenderer = VideoRenderer()
    ) {
        self.webRTCSession = webRTCSession
        self.audioCoordinator = audioCoordinator
        self.videoRenderer = videoRenderer
    }

    public static func preview() -> NativeStreamingEngine {
        NativeStreamingEngine()
    }

    public func prepare(session: StreamingSession) async throws {
        currentSession = session
        webRTCSession.prepareConnection()
        audioCoordinator.prepare()
        videoRenderer.attach(trackID: session.id)
    }

    public func start(session: StreamingSession) async throws {
        if currentSession?.id != session.id {
            try await prepare(session: session)
        }

        currentSession = session
        webRTCSession.connect()
        audioCoordinator.activate()
        videoRenderer.markStreamingActive()
    }

    public func stop() async {
        currentSession = nil
        webRTCSession.disconnect()
        audioCoordinator.deactivate()
        videoRenderer.reset()
    }

    public func sendRumble(intensity: Double) {
        webRTCSession.sendRumble(intensity: intensity)
    }
}
