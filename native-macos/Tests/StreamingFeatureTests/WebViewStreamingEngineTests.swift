import Foundation
import NetworkingKit
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
    #expect(html.contains("<div class=\"status\" id=\"status\">Starting stream...</div>"))
    #expect(html.contains("display: none;"))
    #expect(html.contains("collectLocalIceCandidates"))
    #expect(html.contains("exchangeLocalIceCandidates"))
    #expect(html.contains("local ICE collection"))
    #expect(html.contains("local ICE publish complete"))
    #expect(html.contains("candidateSummary"))
    #expect(html.contains("candidateDetail"))
    #expect(html.contains("candidateMidSummary"))
    #expect(html.contains("localCandidateDetail"))
    #expect(html.contains("remoteCandidateDetail"))
    #expect(html.contains("localCandidateMidSummary"))
    #expect(html.contains("remoteCandidateMidSummary"))
    #expect(html.contains("remoteCandidateApplySummary"))
    #expect(html.contains("publishLocalIceCandidates"))
    #expect(html.contains("applyRemoteDescription"))
    #expect(html.contains("addRemoteIceCandidate"))
    #expect(html.contains("emitWebRTCStats"))
    #expect(html.contains("normalizeMLineIndex"))
    #expect(html.contains("sdpMLineIndex: normalizeMLineIndex(candidate.sdpMLineIndex)"))
    #expect(html.contains("remoteCandidatesApplied"))
    #expect(html.contains("remoteCandidateSummary = candidateSummary(normalizedCandidates)"))
    #expect(html.contains("Remote ICE candidate failures"))
    #expect(html.contains("connectionstate"))
    #expect(html.contains("video loadedmetadata"))
    #expect(html.contains("Remote ICE applied. Waiting for media..."))
    #expect(html.contains("[0, 500, 1000, 1500, 2500, 3500]"))
    #expect(html.contains("Collecting local ICE candidates..."))
    #expect(html.contains("setRemoteOffer"))
    #expect(html.contains("nativePlayerConfiguration.turnServer"))
    #expect(html.contains("player.bind({ turnServer: nativePlayerConfiguration.turnServer })"))
    #expect(html.contains("player bound with TURN server"))
    #expect(html.contains("player bound without TURN server"))
    #expect(html.contains("setVideoFormat"))
    #expect(html.contains("setButton"))
    #expect(html.contains("pressButtonStart"))
    #expect(html.contains("pressButtonEnd"))
    #expect(html.contains("setMicrophone"))
    #expect(html.contains("startMic"))
    #expect(html.contains("stopMic"))
}

@Test
func compatibilityPlayerPageInjectsTurnServerConfiguration() throws {
    let page = CompatibilityPlayerPage(playerScript: "function xStreamingPlayer() {}")
    let html = page.html(
        for: StreamingFixtures.startedSession,
        configuration: CompatibilityPlayerConfiguration(
            turnServer: TurnServerConfiguration(
                url: "turn:relay.example.com",
                username: "relay-user",
                credential: "relay-secret"
            ),
            videoFormat: "H264"
        )
    )

    #expect(html.contains("\"url\":\"turn:relay.example.com\""))
    #expect(html.contains("\"username\":\"relay-user\""))
    #expect(html.contains("\"credential\":\"relay-secret\""))
    #expect(html.contains("\"videoFormat\":\"H264\""))
}

@Test
@MainActor
func compatibilityEngineAppliesSettingsToPlayerConfiguration() async {
    let engine = WebViewStreamingEngine(
        configuration: .preview,
        bridgeScript: "window.nativeStreamingBridge = {};",
        playerPage: CompatibilityPlayerPage(playerScript: "function xStreamingPlayer() {}")
    )
    let settings = AppSettings(
        locale: AppSettings.defaults.locale,
        useMSAL: AppSettings.defaults.useMSAL,
        fullscreen: AppSettings.defaults.fullscreen,
        resolution: AppSettings.defaults.resolution,
        xhomeAutoConnectServerID: AppSettings.defaults.xhomeAutoConnectServerID,
        xhomeBitrateMode: AppSettings.defaults.xhomeBitrateMode,
        xhomeBitrate: AppSettings.defaults.xhomeBitrate,
        xcloudBitrateMode: AppSettings.defaults.xcloudBitrateMode,
        xcloudBitrate: AppSettings.defaults.xcloudBitrate,
        audioBitrateMode: AppSettings.defaults.audioBitrateMode,
        audioBitrate: AppSettings.defaults.audioBitrate,
        enableAudioControl: AppSettings.defaults.enableAudioControl,
        enableAudioRumble: AppSettings.defaults.enableAudioRumble,
        audioRumbleThreshold: AppSettings.defaults.audioRumbleThreshold,
        preferredGameLanguage: AppSettings.defaults.preferredGameLanguage,
        forceRegionIP: AppSettings.defaults.forceRegionIP,
        codec: AppSettings.defaults.codec,
        pollingRate: AppSettings.defaults.pollingRate,
        coop: AppSettings.defaults.coop,
        vibration: AppSettings.defaults.vibration,
        vibrationMode: AppSettings.defaults.vibrationMode,
        gamepadKernel: AppSettings.defaults.gamepadKernel,
        gamepadMix: AppSettings.defaults.gamepadMix,
        gamepadIndex: AppSettings.defaults.gamepadIndex,
        deadZone: AppSettings.defaults.deadZone,
        edgeCompensation: AppSettings.defaults.edgeCompensation,
        forceTriggerRumble: AppSettings.defaults.forceTriggerRumble,
        powerOn: AppSettings.defaults.powerOn,
        videoFormat: "H265",
        virtualGamepadOpacity: AppSettings.defaults.virtualGamepadOpacity,
        ipv6: AppSettings.defaults.ipv6,
        enableNativeMouseKeyboard: AppSettings.defaults.enableNativeMouseKeyboard,
        mouseSensitive: AppSettings.defaults.mouseSensitive,
        performanceStyle: AppSettings.defaults.performanceStyle,
        turnServer: TurnServerConfiguration(
            url: "turn:relay.example.com",
            username: "relay-user",
            credential: "relay-secret"
        ),
        backgroundKeepalive: AppSettings.defaults.backgroundKeepalive,
        inputMouseKeyboardMapping: AppSettings.defaults.inputMouseKeyboardMapping,
        displayOptions: AppSettings.defaults.displayOptions,
        useVulkan: AppSettings.defaults.useVulkan,
        fsr: AppSettings.defaults.fsr,
        fsrSharpness: AppSettings.defaults.fsrSharpness,
        debug: AppSettings.defaults.debug
    )

    await engine.configure(settings: settings)

    #expect(engine.playerConfiguration.videoFormat == "H265")
    #expect(engine.playerConfiguration.turnServer.url == "turn:relay.example.com")
}

@Test
@MainActor
func compatibilityEngineLoadsDefaultTurnServerWhenSettingsAreEmpty() async {
    let engine = WebViewStreamingEngine(
        configuration: .preview,
        bridgeScript: "window.nativeStreamingBridge = {};",
        playerPage: CompatibilityPlayerPage(playerScript: "function xStreamingPlayer() {}"),
        defaultTurnServerProvider: StubTurnServerProvider(
            turnServer: TurnServerConfiguration(
                url: "turn:default-relay.example.com",
                username: "default-user",
                credential: "default-secret"
            )
        )
    )

    await engine.configure(settings: .defaults)

    #expect(engine.playerConfiguration.turnServer.url == "turn:default-relay.example.com")
    #expect(engine.playerConfiguration.turnServer.username == "default-user")
    #expect(engine.playerConfiguration.turnServer.credential == "default-secret")
}

@Test
func supportTurnServerProviderFetchesDefaultRelayConfig() async throws {
    let session = MockURLSession(responses: [
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "url": "turn:default-relay.example.com",
              "username": "default-user",
              "credential": "default-secret"
            }
            """
        )
    ])
    let provider = SupportTurnServerConfigurationProvider(
        httpClient: HTTPClient(session: session),
        endpoint: URL(string: "https://relay.example.com/server.json")!
    )

    let turnServer = try #require(await provider.loadDefaultTurnServer())

    #expect(turnServer.url == "turn:default-relay.example.com")
    #expect(turnServer.username == "default-user")
    #expect(turnServer.credential == "default-secret")
    #expect(await session.requestURLs == ["https://relay.example.com/server.json"])
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
            "localCandidateDetail": "host/udp/f1/p9002x1,srflx/udp/f2/p53000x1",
            "localCandidateMidSummary": "mid=0/m=0x27",
            "remoteCandidateSummary": "total=12 host=12 srflx=0 relay=0 prflx=0 udp=12 tcp=0 end=1",
            "remoteCandidateDetail": "host/udp/f1/p9002x1",
            "remoteCandidateMidSummary": "mid=0/m=0x12",
            "remoteCandidateApplySummary": "applied=11 fallback=0 failed=0 skipped=0 end=1",
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

    #expect(engine.bridgeStatus == "remote ICE applied | pc=connecting ice=checking local=27 remote=3 videos=1 ready=0 size=0x0 localICE[total=27 host=8 srflx=19 relay=0 prflx=0 udp=27 tcp=0 end=0] localDetail[host/udp/f1/p9002x1,srflx/udp/f2/p53000x1] localMid[mid=0/m=0x27] remoteICE[total=12 host=12 srflx=0 relay=0 prflx=0 udp=12 tcp=0 end=1] remoteDetail[host/udp/f1/p9002x1] remoteMid[mid=0/m=0x12] remoteApply[applied=11 fallback=0 failed=0 skipped=0 end=1] stats[local(host=8,srflx=19,relay=0) remote(host=12,srflx=0,relay=0) pairs=0 nominated=0 selected=0]")
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

private struct StubTurnServerProvider: TurnServerConfigurationProvider {
    let turnServer: TurnServerConfiguration?

    func loadDefaultTurnServer() async -> TurnServerConfiguration? {
        turnServer
    }
}

private final class MockURLSession: URLSessionProviding, @unchecked Sendable {
    struct Response: Sendable {
        let statusCode: Int
        let body: String
    }

    private let responses: [Response]
    private let capture = RequestCapture()
    private var index = 0

    init(responses: [Response]) {
        self.responses = responses
    }

    var requestURLs: [String] {
        get async { await capture.requestURLs }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        await capture.record(request)
        let response = responses[index]
        index += 1
        let url = try #require(request.url)
        let httpResponse = try #require(
            HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: nil,
                headerFields: nil
            )
        )
        return (Data(response.body.utf8), httpResponse)
    }
}

private actor RequestCapture {
    private(set) var requestURLs: [String] = []

    func record(_ request: URLRequest) {
        requestURLs.append(request.url?.absoluteString ?? "")
    }
}
