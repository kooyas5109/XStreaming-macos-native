import SharedDomain
import Testing
@testable import StreamingFeature

@MainActor
@Test
func nativeEngineExposesSameCapabilitiesAsCompatibilityEngine() throws {
    let engine: any StreamingEngineProtocol = NativeStreamingEngine.preview()
    #expect(engine.capabilities.supportsVideo == true)
    #expect(engine.capabilities.supportsRumble == true)
}

@MainActor
@Test
func nativeEnginePreparesAudioVideoAndSessionState() async throws {
    let session = StreamingSession(
        id: "native-stream-1",
        targetID: "console-1",
        sessionPath: "/native/session-1",
        kind: .home,
        state: .readyToConnect
    )
    let engine = NativeStreamingEngine.preview()

    try await engine.prepare(session: session)

    #expect(engine.currentSession?.id == "native-stream-1")
    #expect(engine.audioCoordinator.isPrepared == true)
    #expect(engine.webRTCSession.state == .prepared)
    #expect(engine.videoRenderer.attachedTrackID == "native-stream-1")
}

@MainActor
@Test
func nativeEngineStartsAndStopsStreamingPipeline() async throws {
    let session = StreamingSession(
        id: "native-stream-2",
        targetID: "title-1",
        sessionPath: "/native/session-2",
        kind: .cloud,
        state: .readyToConnect
    )
    let engine = NativeStreamingEngine.preview()

    try await engine.start(session: session)
    engine.sendRumble(intensity: 0.6)

    #expect(engine.audioCoordinator.isActive == true)
    #expect(engine.webRTCSession.state == .connected)
    #expect(engine.webRTCSession.lastRumbleIntensity == 0.6)

    await engine.stop()

    #expect(engine.audioCoordinator.isActive == false)
    #expect(engine.webRTCSession.state == .disconnected)
    #expect(engine.videoRenderer.attachedTrackID == nil)
}
