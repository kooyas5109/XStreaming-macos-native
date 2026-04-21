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
    #expect(html.contains("typeof exported.default === \"function\""))
    #expect(html.contains("return exported.default"))
    #expect(html.contains("new Player"))
    #expect(html.contains("xStreamingPlayer constructor is unavailable."))
    #expect(html.contains("sdp-offer"))
    #expect(html.contains("ice-candidates"))
    #expect(html.contains("publishedLocalCandidates"))
    #expect(html.contains("publishedLocalCandidateValues"))
    #expect(html.contains("candidateSummary"))
    #expect(html.contains("emitWebRTCStats"))
    #expect(html.contains("normalizeMLineIndex"))
    #expect(html.contains("sdpMLineIndex: normalizeMLineIndex(candidate.sdpMLineIndex)"))
    #expect(html.contains("remoteCandidatesApplied"))
    #expect(html.contains("remoteCandidateSummary = candidateSummary(normalizedCandidates)"))
    #expect(html.contains("Failed to apply remote ICE"))
    #expect(html.contains("connectionstate"))
    #expect(html.contains("video loadedmetadata"))
    #expect(html.contains("Remote ICE applied. Waiting for media..."))
    #expect(html.contains("[0, 500, 1000, 2000, 4000, 7000, 10000]"))
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

@Test
@MainActor
func compatibilityEngineSummarizesBridgeDiagnostics() async throws {
    let engine = WebViewStreamingEngine(
        configuration: .preview,
        bridgeScript: "window.nativeStreamingBridge = {};",
        playerPage: CompatibilityPlayerPage(playerScript: "function xStreamingPlayer() {}")
    )

    try await engine.handleBridgeMessage([
        "type": "diagnostic",
        "payload": [
            "message": "remote ICE applied",
            "connectionState": "connecting",
            "iceConnectionState": "checking",
            "localCandidatesSent": 2,
            "videoCount": 1,
            "videos": [
                [
                    "readyState": 0,
                    "width": 0,
                    "height": 0
                ]
            ]
        ]
    ])

    #expect(engine.bridgeStatus == "remote ICE applied | pc=connecting ice=checking local=2 remote=0 videos=1 ready=0 size=0x0")
}

@Test
@MainActor
func compatibilityEngineSummarizesRemoteCandidateDiagnostics() async throws {
    let engine = WebViewStreamingEngine(
        configuration: .preview,
        bridgeScript: "window.nativeStreamingBridge = {};",
        playerPage: CompatibilityPlayerPage(playerScript: "function xStreamingPlayer() {}")
    )

    try await engine.handleBridgeMessage([
        "type": "diagnostic",
        "payload": [
            "message": "remote ICE applied",
            "connectionState": "connecting",
            "iceConnectionState": "checking",
            "localCandidatesSent": 27,
            "remoteCandidatesApplied": 3,
            "localCandidateSummary": "total=27 host=8 srflx=19 relay=0 prflx=0 udp=27 tcp=0 end=0",
            "remoteCandidateSummary": "total=12 host=12 srflx=0 relay=0 prflx=0 udp=12 tcp=0 end=1",
            "webRTCStats": "local(host=8,srflx=19,relay=0) remote(host=12,srflx=0,relay=0) pairs=0 nominated=0 selected=0",
            "videoCount": 1,
            "videos": [
                [
                    "readyState": 0,
                    "width": 0,
                    "height": 0
                ]
            ]
        ]
    ])

    #expect(engine.bridgeStatus == "remote ICE applied | pc=connecting ice=checking local=27 remote=3 videos=1 ready=0 size=0x0 localICE[total=27 host=8 srflx=19 relay=0 prflx=0 udp=27 tcp=0 end=0] remoteICE[total=12 host=12 srflx=0 relay=0 prflx=0 udp=12 tcp=0 end=1] stats[local(host=8,srflx=19,relay=0) remote(host=12,srflx=0,relay=0) pairs=0 nominated=0 selected=0]")
}

@Test
@MainActor
func compatibilityEngineSerializesRemoteIceMLineIndexAsNumber() {
    let json = WebViewStreamingEngine.javascriptJSON([
        StreamingICECandidate(
            messageType: "iceCandidate",
            candidate: "candidate:1 1 UDP 1 127.0.0.1 9002 typ host",
            sdpMid: "0",
            sdpMLineIndex: "0"
        )
    ])

    #expect(json.contains("\"sdpMLineIndex\":0"))
    #expect(!json.contains("\"sdpMLineIndex\":\"0\""))
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
