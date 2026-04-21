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

    private let configuration: WebViewStreamingConfiguration
    private let logger: AppLogger
    private weak var webView: WKWebView?
    private var signaling: StreamingSignalingClient?

    public init(
        configuration: WebViewStreamingConfiguration,
        bridgeScript: String,
        playerPage: CompatibilityPlayerPage,
        logger: AppLogger = AppLogger(category: "WebRTC")
    ) {
        self.configuration = configuration
        self.bridgeScript = bridgeScript
        self.playerPage = playerPage
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
            webView.loadHTMLString(playerPage.html(for: session), baseURL: configuration.baseURL)
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
        guard
            let session = currentSession,
            let signaling,
            let payload = payload as? [String: Any],
            let sdp = payload["sdp"] as? String
        else {
            throw WebViewStreamingEngineError.invalidBridgeMessage
        }

        let answer = try await signaling.exchangeSDP(sessionID: session.id, offerSDP: sdp)
        bridgeStatus = "Remote answer received."
        let script = "window.xstreamingNativePlayer?.setRemoteOffer?.(\(Self.javascriptString(answer.sdp)))"
        _ = try? await webView?.evaluateJavaScript(script)
    }

    private func handleICECandidates(_ payload: Any?) async throws {
        guard
            let session = currentSession,
            let signaling,
            let payload = payload as? [String: Any],
            let rawCandidates = payload["candidates"] as? [[String: Any]]
        else {
            throw WebViewStreamingEngineError.invalidBridgeMessage
        }

        let candidates = rawCandidates.compactMap(Self.makeICECandidate)
        guard candidates.isEmpty == false else {
            return
        }

        let remoteCandidates: [StreamingICECandidate]
        if let streamingService = signaling as? StreamingService {
            remoteCandidates = try await streamingService.exchangeICE(sessionID: session.id, candidates: candidates)
        } else {
            remoteCandidates = try await signaling.exchangeICE(sessionID: session.id, candidate: candidates[0].candidate)
        }

        bridgeStatus = "Remote ICE candidates received."
        let script = "window.xstreamingNativePlayer?.setIceCandidates?.(\(Self.javascriptJSON(remoteCandidates)))"
        _ = try? await webView?.evaluateJavaScript(script)
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
            remoteSummary.map { "remoteICE[\($0)]" },
            stats.map { "stats[\($0)]" }
        ].compactMap { $0 }.joined(separator: " ")
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

    private static func javascriptString(_ value: String) -> String {
        let data = try? JSONEncoder().encode(value)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
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
            try? await handleBridgeMessage(message.body)
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
