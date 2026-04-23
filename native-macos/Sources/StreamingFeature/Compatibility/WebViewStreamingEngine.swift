import Foundation
import Combine
import WebKit
import SharedDomain
import SupportKit

public enum WebViewStreamingEngineError: Error, Equatable, Sendable {
    case invalidSessionURL
    case bridgeScriptUnavailable
    case playerScriptUnavailable
    case invalidBridgeMessage
}

public struct WebViewStreamingConfiguration: Equatable, Sendable {
    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public static let preview = WebViewStreamingConfiguration(
        baseURL: URL(string: "https://streaming-preview.local")!
    )
}

@MainActor
public final class WebViewStreamingEngine: NSObject, ObservableObject, StreamingEngineProtocol {
    public let capabilities = StreamingEngineCapabilities(
        supportsVideo: true,
        supportsAudio: true,
        supportsPointerInput: true,
        supportsControllerInput: true,
        supportsNativeOverlay: true,
        supportsRumble: false
    )

    public private(set) var currentSession: StreamingSession?
    public private(set) var currentURL: URL?
    @Published public private(set) var bridgeStatus: String = "Idle"
    @Published public private(set) var bridgeError: String?
    public let bridgeScript: String
    public let playerPage: CompatibilityPlayerPage
    public private(set) var playerConfiguration = CompatibilityPlayerConfiguration()

    private let configuration: WebViewStreamingConfiguration
    private let defaultTurnServerProvider: TurnServerConfigurationProvider
    private let logger: AppLogger
    private weak var webView: WKWebView?
    private var signaling: StreamingSignalingClient?

    public init(
        configuration: WebViewStreamingConfiguration,
        bridgeScript: String,
        playerPage: CompatibilityPlayerPage,
        defaultTurnServerProvider: TurnServerConfigurationProvider = SupportTurnServerConfigurationProvider(),
        logger: AppLogger = AppLogger(category: "WebRTC")
    ) {
        self.configuration = configuration
        self.bridgeScript = bridgeScript
        self.playerPage = playerPage
        self.defaultTurnServerProvider = defaultTurnServerProvider
        self.logger = logger
    }

    public convenience init(configuration: WebViewStreamingConfiguration) throws {
        try self.init(
            configuration: configuration,
            bridgeScript: BridgeScriptLoader.load(),
            playerPage: CompatibilityPlayerPage(playerScript: CompatibilityPlayerAssetLoader.loadPlayerScript())
        )
    }

    public static func preview() -> WebViewStreamingEngine {
        try! WebViewStreamingEngine(configuration: .preview)
    }

    public func configure(settings: AppSettings) async {
        var turnServer = settings.turnServer
        var turnMode = "custom"

        if turnServer.isComplete == false {
            if let defaultTurnServer = await defaultTurnServerProvider.loadDefaultTurnServer() {
                turnServer = defaultTurnServer
                turnMode = "default-relay"
            } else {
                turnMode = "none"
            }
        }

        playerConfiguration = CompatibilityPlayerConfiguration(settings: settings, turnServer: turnServer)
        let videoFormat = playerConfiguration.videoFormat.isEmpty ? "default" : playerConfiguration.videoFormat
        logger.info("Configured WebView player: turn=\(turnMode), videoFormat=\(videoFormat)")
    }

    public func attach(webView: WKWebView) {
        self.webView = webView

        let userScript = WKUserScript(
            source: bridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "streamingBridge")
        webView.configuration.userContentController.addUserScript(userScript)
        webView.configuration.userContentController.add(self, name: "streamingBridge")
    }

    public func prepare(session: StreamingSession) async throws {
        let url = try makeStreamURL(for: session)
        currentSession = session
        currentURL = url
        bridgeStatus = "Loading player surface..."
        bridgeError = nil

        if let webView {
            webView.loadHTMLString(
                playerPage.html(for: session, configuration: playerConfiguration),
                baseURL: configuration.baseURL
            )
        }
    }

    public func start(session: StreamingSession, signaling: StreamingSignalingClient? = nil) async throws {
        self.signaling = signaling
        bridgeStatus = "Starting player..."
        bridgeError = nil
        if currentSession?.id != session.id {
            try await prepare(session: session)
        }

        if let webView {
            _ = try? await webView.evaluateJavaScript("window.xstreamingNativePlayer?.start?.()")
        }
    }

    public func sendControlEvent(_ event: StreamingControlEvent) async throws {
        let script = Self.controlScript(for: event)
        guard script.isEmpty == false else { return }
        _ = try? await webView?.evaluateJavaScript(script)
    }

    public func sendGamepadState(_ state: StreamingGamepadState) async {
        let script = Self.gamepadStateScript(for: state)
        logger.info("Sending keyboard gamepad state: \(Self.gamepadStateSummary(state))")
        _ = try? await webView?.evaluateJavaScript(script)
    }

    public func stop() async {
        _ = try? await webView?.evaluateJavaScript("window.xstreamingNativePlayer?.stop?.()")
        signaling = nil
        currentSession = nil
        currentURL = nil
        bridgeStatus = "Stopped"
        bridgeError = nil
        webView?.loadHTMLString("", baseURL: nil)
    }

    func makeStreamURL(for session: StreamingSession) throws -> URL {
        guard let url = URL(string: session.sessionPath, relativeTo: configuration.baseURL)?.absoluteURL else {
            throw WebViewStreamingEngineError.invalidSessionURL
        }
        return url
    }

    func handleBridgeMessage(_ message: Any) async throws {
        guard
            let dictionary = message as? [String: Any],
            let type = dictionary["type"] as? String
        else {
            throw WebViewStreamingEngineError.invalidBridgeMessage
        }

        switch type {
        case "sdp-offer":
            try await handleSDPOffer(dictionary["payload"])
        case "ice-candidates":
            try await handleICECandidates(dictionary["payload"])
        case "status":
            bridgeStatus = bridgeMessage(from: dictionary["payload"]) ?? bridgeStatus
        case "error":
            bridgeError = bridgeMessage(from: dictionary["payload"]) ?? "Unknown player error"
            logger.error("WebView stream error: \(bridgeError ?? "unknown")")
        case "diagnostic":
            if let diagnostic = diagnosticMessage(from: dictionary["payload"]) {
                bridgeStatus = diagnostic
                logger.info("WebView stream diagnostic: \(diagnostic)")
            }
        default:
            break
        }
    }

    private func handleSDPOffer(_ payload: Any?) async throws {
        guard let session = currentSession else {
            throw bridgeFailure("Cannot exchange SDP offer: missing current session.")
        }
        guard let signaling else {
            throw bridgeFailure("Cannot exchange SDP offer: missing signaling client.")
        }
        guard
            let payload = payload as? [String: Any],
            let sdp = payload["sdp"] as? String
        else {
            throw bridgeFailure("Cannot exchange SDP offer: invalid bridge payload.")
        }

        logger.info("Exchanging SDP offer for session \(session.id)")
        let answer = try await signaling.exchangeSDP(sessionID: session.id, offerSDP: sdp)
        bridgeStatus = "Remote answer received."
        logger.info("Applying remote SDP answer for session \(session.id)")
        let script = "window.xstreamingNativePlayer?.setRemoteOffer?.(\(Self.javascriptString(answer.sdp)))"
        _ = try? await webView?.evaluateJavaScript(script)
    }

    private func handleICECandidates(_ payload: Any?) async throws {
        guard let session = currentSession else {
            throw bridgeFailure("Cannot exchange ICE candidates: missing current session.")
        }
        guard let signaling else {
            throw bridgeFailure("Cannot exchange ICE candidates: missing signaling client.")
        }
        guard
            let payload = payload as? [String: Any],
            let rawCandidates = payload["candidates"] as? [[String: Any]]
        else {
            throw bridgeFailure("Cannot exchange ICE candidates: invalid bridge payload.")
        }

        let candidates = rawCandidates.compactMap(Self.makeICECandidate)
        guard candidates.isEmpty == false else {
            return
        }
        logger.info("Publishing local ICE candidates: \(Self.redactedCandidateSummary(candidates))")

        let remoteCandidates: [StreamingICECandidate]
        if let streamingService = signaling as? StreamingService {
            remoteCandidates = try await streamingService.exchangeICE(sessionID: session.id, candidates: candidates)
        } else {
            remoteCandidates = try await signaling.exchangeICE(sessionID: session.id, candidate: candidates[0].candidate)
        }
        logger.info("Applying remote ICE candidates: \(Self.redactedCandidateSummary(remoteCandidates))")

        bridgeStatus = "Remote ICE candidates received."
        let script = "window.xstreamingNativePlayer?.setIceCandidates?.(\(Self.javascriptJSON(remoteCandidates)))"
        _ = try? await webView?.evaluateJavaScript(script)
    }

    private func bridgeFailure(_ message: String) -> WebViewStreamingEngineError {
        bridgeError = message
        logger.error("WebView bridge failure: \(message)")
        return .invalidBridgeMessage
    }

    private func bridgeMessage(from payload: Any?) -> String? {
        if let message = payload as? String {
            return message
        }

        guard let dictionary = payload as? [String: Any] else {
            return nil
        }
        return dictionary["message"] as? String
    }

    private func diagnosticMessage(from payload: Any?) -> String? {
        guard let dictionary = payload as? [String: Any] else {
            return nil
        }

        let message = dictionary["message"] as? String ?? "diagnostic"
        let connection = dictionary["connectionState"] as? String ?? "unknown"
        let ice = dictionary["iceConnectionState"] as? String ?? "unknown"
        let videoCount = dictionary["videoCount"] as? Int ?? 0
        let localCandidates = dictionary["localCandidatesSent"] as? Int ?? 0
        let remoteCandidates = dictionary["remoteCandidatesApplied"] as? Int ?? 0
        let localSummary = dictionary["localCandidateSummary"] as? String
        let remoteSummary = dictionary["remoteCandidateSummary"] as? String
        let localDetail = dictionary["localCandidateDetail"] as? String
        let remoteDetail = dictionary["remoteCandidateDetail"] as? String
        let localMid = dictionary["localCandidateMidSummary"] as? String
        let remoteMid = dictionary["remoteCandidateMidSummary"] as? String
        let remoteApply = dictionary["remoteCandidateApplySummary"] as? String
        let stats = dictionary["webRTCStats"] as? String
        let firstVideo = (dictionary["videos"] as? [[String: Any]])?.first
        let readyState = firstVideo?["readyState"] as? Int
        let size: String
        if let width = firstVideo?["width"] as? Int,
           let height = firstVideo?["height"] as? Int {
            size = "\(width)x\(height)"
        } else {
            size = "none"
        }
        let ready = readyState.map(String.init) ?? "none"
        let base = "\(message) | pc=\(connection) ice=\(ice) local=\(localCandidates) remote=\(remoteCandidates) videos=\(videoCount) ready=\(ready) size=\(size)"
        return [
            base,
            localSummary.map { "localICE[\($0)]" },
            localDetail.map { "localDetail[\($0)]" },
            localMid.map { "localMid[\($0)]" },
            remoteSummary.map { "remoteICE[\($0)]" },
            remoteDetail.map { "remoteDetail[\($0)]" },
            remoteMid.map { "remoteMid[\($0)]" },
            remoteApply.map { "remoteApply[\($0)]" },
            stats.map { "stats[\($0)]" }
        ].compactMap { $0 }.joined(separator: " ")
    }

    private static func redactedCandidateSummary(_ candidates: [StreamingICECandidate]) -> String {
        var counts: [String: Int] = [:]
        var ended = 0
        for candidate in candidates {
            if candidate.candidate == "a=end-of-candidates" {
                ended += 1
                continue
            }

            let parts = candidate.candidate
                .replacingOccurrences(of: "a=", with: "")
                .split(separator: " ", omittingEmptySubsequences: true)
                .map(String.init)
            guard parts.count >= 8 else {
                counts["malformed"] = (counts["malformed"] ?? 0) + 1
                continue
            }

            let protocolName = parts[2].lowercased()
            let typeIndex = parts.firstIndex(of: "typ")
            let candidateType = typeIndex.flatMap { index in
                parts.indices.contains(index + 1) ? parts[index + 1].lowercased() : nil
            } ?? "unknown"
            let key = "\(candidateType)/\(protocolName)"
            counts[key] = (counts[key] ?? 0) + 1
        }

        let values = counts
            .sorted { first, second in first.key < second.key }
            .map { "\($0.key)=\($0.value)" }
        return (values + ["end=\(ended)", "total=\(candidates.count)"]).joined(separator: " ")
    }

    private static func makeICECandidate(_ dictionary: [String: Any]) -> StreamingICECandidate? {
        guard let candidate = dictionary["candidate"] as? String else {
            return nil
        }

        let mLineIndex: String?
        if let value = dictionary["sdpMLineIndex"] as? Int {
            mLineIndex = String(value)
        } else if let value = dictionary["sdpMLineIndex"] as? Double {
            mLineIndex = String(Int(value))
        } else {
            mLineIndex = dictionary["sdpMLineIndex"] as? String
        }

        return StreamingICECandidate(
            messageType: dictionary["messageType"] as? String ?? "iceCandidate",
            candidate: candidate,
            sdpMid: dictionary["sdpMid"] as? String,
            sdpMLineIndex: mLineIndex
        )
    }

    static func controlScript(for event: StreamingControlEvent) -> String {
        switch event {
        case .button(let button, let phase):
            return "window.xstreamingNativePlayer?.setButton?.(\(javascriptString(button.rawValue)), \(javascriptString(phase.rawValue)))"
        case .microphone(let active):
            return "window.xstreamingNativePlayer?.setMicrophone?.(\(active ? "true" : "false"))"
        case .text:
            return ""
        }
    }

    static func gamepadStateScript(for state: StreamingGamepadState) -> String {
        let buttonValue: (StreamingControlButton) -> String = { button in
            state.buttons.contains(button) ? "1" : "0"
        }

        return """
        window.xstreamingNativePlayer?.setGamepadState?.({
          GamepadIndex: \(state.gamepadIndex),
          A: \(buttonValue(.buttonA)),
          B: \(buttonValue(.buttonB)),
          X: \(buttonValue(.buttonX)),
          Y: \(buttonValue(.buttonY)),
          LeftShoulder: \(buttonValue(.leftShoulder)),
          RightShoulder: \(buttonValue(.rightShoulder)),
          LeftTrigger: \(javascriptNumber(state.leftTrigger)),
          RightTrigger: \(javascriptNumber(state.rightTrigger)),
          View: \(buttonValue(.view)),
          Menu: \(buttonValue(.menu)),
          LeftThumb: \(buttonValue(.leftThumbPress)),
          RightThumb: \(buttonValue(.rightThumbPress)),
          DPadUp: \(buttonValue(.dpadUp)),
          DPadDown: \(buttonValue(.dpadDown)),
          DPadLeft: \(buttonValue(.dpadLeft)),
          DPadRight: \(buttonValue(.dpadRight)),
          Nexus: \(buttonValue(.nexus)),
          LeftThumbXAxis: \(javascriptNumber(state.leftThumbX)),
          LeftThumbYAxis: \(javascriptNumber(state.leftThumbY)),
          RightThumbXAxis: \(javascriptNumber(state.rightThumbX)),
          RightThumbYAxis: \(javascriptNumber(state.rightThumbY)),
          Dirty: true,
          Virtual: true
        })
        """
    }

    private static func javascriptString(_ value: String) -> String {
        let data = try? JSONEncoder().encode(value)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }

    private static func javascriptNumber(_ value: Double) -> String {
        let clamped = min(1, max(-1, value))
        return String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), clamped)
    }

    private static func gamepadStateSummary(_ state: StreamingGamepadState) -> String {
        let buttons = state.buttons
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
        let activeButtons = buttons.isEmpty ? "none" : buttons
        return "buttons=\(activeButtons) lt=\(state.leftTrigger) rt=\(state.rightTrigger) lx=\(state.leftThumbX) ly=\(state.leftThumbY) rx=\(state.rightThumbX) ry=\(state.rightThumbY)"
    }

    static func javascriptJSON(_ candidates: [StreamingICECandidate]) -> String {
        let values = candidates.map { candidate in
            [
                "candidate": candidate.candidate,
                "sdpMid": candidate.sdpMid ?? "0",
                "sdpMLineIndex": Int(candidate.sdpMLineIndex ?? "0") ?? 0
            ] as [String: Any]
        }
        let data = try? JSONSerialization.data(withJSONObject: values)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }
}

extension WebViewStreamingEngine: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Task { @MainActor in
            do {
                try await handleBridgeMessage(message.body)
            } catch {
                let message = "WebView bridge message failed: \(String(describing: error))"
                bridgeError = message
                logger.error("\(message)")
            }
        }
    }
}

enum BridgeScriptLoader {
    static func load(bundle: Bundle = .module) throws -> String {
        guard let url = bundle.url(forResource: "BridgeScript", withExtension: "js") else {
            throw WebViewStreamingEngineError.bridgeScriptUnavailable
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
