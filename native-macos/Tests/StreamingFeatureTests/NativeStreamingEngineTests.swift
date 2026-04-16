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

@MainActor
@Test
func nativeEngineRunsSignalingBeforeActivatingPipeline() async throws {
    let session = StreamingSession(
        id: "native-stream-3",
        targetID: "console-1",
        sessionPath: "/native/session-3",
        kind: .home,
        state: .started
    )
    let signaling = TestSignalingClient()
    let engine = NativeStreamingEngine.preview()

    try await engine.start(session: session, signaling: signaling)

    #expect(engine.webRTCSession.state == .connected)
    #expect(engine.webRTCSession.localOfferSDP?.contains("native-stream-3") == true)
    #expect(engine.webRTCSession.remoteAnswerSDP == "v=0\r\nremote-answer")
    #expect(engine.webRTCSession.localICECandidate?.contains("a=candidate:") == true)
    #expect(engine.webRTCSession.remoteICECandidates == [
        StreamingICECandidate(
            messageType: "iceCandidate",
            candidate: "a=candidate:2 1 UDP 1 10.0.0.2 9002 typ host",
            sdpMid: "0",
            sdpMLineIndex: "0"
        )
    ])
    #expect(signaling.sdpCalls.count == 1)
    #expect(signaling.iceCalls.count == 1)
    #expect(engine.audioCoordinator.isActive == true)
    #expect(engine.videoRenderer.statusText == "Native stream active")
}

private final class TestSignalingClient: StreamingSignalingClient, @unchecked Sendable {
    private(set) var sdpCalls: [(sessionID: String, offerSDP: String)] = []
    private(set) var iceCalls: [(sessionID: String, candidate: String)] = []

    func exchangeSDP(sessionID: String, offerSDP: String) async throws -> StreamingSDPAnswer {
        sdpCalls.append((sessionID, offerSDP))
        return StreamingSDPAnswer(messageType: "answer", sdp: "v=0\r\nremote-answer")
    }

    func exchangeICE(sessionID: String, candidate: String) async throws -> [StreamingICECandidate] {
        iceCalls.append((sessionID, candidate))
        return [
            StreamingICECandidate(
                messageType: "iceCandidate",
                candidate: "a=candidate:2 1 UDP 1 10.0.0.2 9002 typ host",
                sdpMid: "0",
                sdpMLineIndex: "0"
            )
        ]
    }
}
