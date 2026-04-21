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

    #expect(html.contains("window.xStreamingPlayer || window.xstreamingPlayer"))
    #expect(html.contains("new Player"))
    #expect(html.contains("xStreamingPlayer constructor is unavailable."))
    #expect(html.contains("sdp-offer"))
    #expect(html.contains("ice-candidates"))
    #expect(html.contains("localIcePublished"))
    #expect(html.contains("2000"))
    #expect(html.contains("setRemoteOffer"))
    #expect(html.contains("setButton"))
    #expect(html.contains("pressButtonStart"))
    #expect(html.contains("pressButtonEnd"))
    #expect(html.contains("setMicrophone"))
    #expect(html.contains("startMic"))
    #expect(html.contains("stopMic"))
}

@Test
@MainActor
func compatibilityEngineBuildsPhaseAwareButtonScripts() {
    let pressScript = WebViewStreamingEngine.controlScript(for: .button(.nexus, .began))
    let releaseScript = WebViewStreamingEngine.controlScript(for: .button(.nexus, .ended))
    let microphoneScript = WebViewStreamingEngine.controlScript(for: .microphone(active: true))

    #expect(pressScript.contains("setButton"))
    #expect(pressScript.contains("\"Nexus\""))
    #expect(pressScript.contains("\"began\""))
    #expect(releaseScript.contains("\"ended\""))
    #expect(microphoneScript.contains("setMicrophone"))
    #expect(microphoneScript.contains("true"))
}

@Test
func compatibilityPlayerAssetLoaderFindsBundledPlayerScript() throws {
    let script = try CompatibilityPlayerAssetLoader.loadPlayerScript()

    #expect(script.contains("xstreamingPlayer"))
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
    #expect(engine.bridgeStatus == "Remote answer received.")
}

@Test
@MainActor
func compatibilityEngineRecordsBridgeStatusAndErrors() async throws {
    let engine = WebViewStreamingEngine(
        configuration: .preview,
        bridgeScript: "window.nativeStreamingBridge = {};",
        playerPage: CompatibilityPlayerPage(playerScript: "function xStreamingPlayer() {}")
    )

    try await engine.handleBridgeMessage([
        "type": "status",
        "payload": ["message": "Negotiating network path..."]
    ])
    try await engine.handleBridgeMessage([
        "type": "error",
        "payload": ["message": "Failed to create stream offer."]
    ])

    #expect(engine.bridgeStatus == "Negotiating network path...")
    #expect(engine.bridgeError == "Failed to create stream offer.")
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
