import Foundation
import SharedDomain
import Testing
@testable import StreamingFeature

@Test
@MainActor
func compatibilityEngineImplementsStreamingProtocol() throws {
    let engine: any StreamingEngineProtocol = WebViewStreamingEngine.preview()
    #expect(engine.capabilities.supportsVideo == true)
    #expect(engine.capabilities.supportsPointerInput == true)
}

@Test
@MainActor
func compatibilityEngineBuildsSessionURLFromConfiguration() async throws {
    let session = StreamingSession(
        id: "stream-1",
        targetID: "title-1",
        sessionPath: "/play/session-1",
        kind: .cloud,
        state: .readyToConnect
    )
    let engine = WebViewStreamingEngine(
        configuration: WebViewStreamingConfiguration(
            baseURL: URL(string: "https://stream.example.com")!
        ),
        bridgeScript: "window.nativeStreamingBridge = {};",
        playerPage: CompatibilityPlayerPage(playerScript: "window.xStreamingPlayer = function () {};")
    )

    try await engine.prepare(session: session)

    #expect(engine.currentURL?.absoluteString == "https://stream.example.com/play/session-1")
    #expect(engine.currentSession?.id == "stream-1")
}

@Test
func compatibilityBridgeScriptExposesNativeHooks() throws {
    let script = try BridgeScriptLoader.load()

    #expect(script.contains("nativeStreamingBridge"))
    #expect(script.contains("requestFullscreen"))
    #expect(script.contains("ice-candidate"))
}

@Test
func compatibilityPlayerPageBootstrapsXStreamingPlayer() throws {
    let page = CompatibilityPlayerPage(playerScript: "function xStreamingPlayer() {}")
    let html = page.html(for: StreamingFixtures.startedSession)

    #expect(html.contains("new xStreamingPlayer"))
    #expect(html.contains("sdp-offer"))
    #expect(html.contains("ice-candidates"))
    #expect(html.contains("setRemoteOffer"))
}

@Test
func compatibilityPlayerAssetLoaderFindsBundledPlayerScript() throws {
    let script = try CompatibilityPlayerAssetLoader.loadPlayerScript()

    #expect(script.contains("xStreamingPlayer"))
}

@Test
@MainActor
func compatibilityEngineExchangesSDPOffersFromBridge() async throws {
    let engine = WebViewStreamingEngine(
        configuration: .preview,
        bridgeScript: "window.nativeStreamingBridge = {};",
        playerPage: CompatibilityPlayerPage(playerScript: "function xStreamingPlayer() {}")
    )
    try await engine.prepare(session: StreamingFixtures.startedSession)
    try await engine.start(session: StreamingFixtures.startedSession, signaling: TestBridgeSignalingClient())

    try await engine.handleBridgeMessage([
        "type": "sdp-offer",
        "payload": [
            "sessionID": "stream-session-1",
            "sdp": "v=0\r\ncompat-offer"
        ]
    ])

    let calls = await TestBridgeSignalingClient.shared.sdpCalls
    #expect(calls == ["stream-session-1:v=0\r\ncompat-offer"])
}

private actor BridgeSignalingRecorder {
    var sdpCalls: [String] = []

    func recordSDP(_ call: String) {
        sdpCalls.append(call)
    }
}

private struct TestBridgeSignalingClient: StreamingSignalingClient {
    static let shared = BridgeSignalingRecorder()

    func exchangeSDP(sessionID: String, offerSDP: String) async throws -> StreamingSDPAnswer {
        await Self.shared.recordSDP("\(sessionID):\(offerSDP)")
        return StreamingSDPAnswer(messageType: "answer", sdp: "v=0\r\ncompat-answer")
    }

    func exchangeICE(sessionID: String, candidate: String) async throws -> [StreamingICECandidate] {
        [
            StreamingICECandidate(
                messageType: "iceCandidate",
                candidate: "a=candidate:1 1 UDP 1 127.0.0.1 9002 typ host",
                sdpMid: "0",
                sdpMLineIndex: "0"
            )
        ]
    }
}
