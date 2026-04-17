import Foundation
import WebKit
import SharedDomain

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
public final class WebViewStreamingEngine: NSObject, StreamingEngineProtocol {
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
    public let bridgeScript: String
    public let playerPage: CompatibilityPlayerPage

    private let configuration: WebViewStreamingConfiguration
    private weak var webView: WKWebView?
    private var signaling: StreamingSignalingClient?

    public init(
        configuration: WebViewStreamingConfiguration,
        bridgeScript: String,
        playerPage: CompatibilityPlayerPage
    ) {
        self.configuration = configuration
        self.bridgeScript = bridgeScript
        self.playerPage = playerPage
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

        if let webView {
            webView.loadHTMLString(playerPage.html(for: session), baseURL: configuration.baseURL)
        }
    }

    public func start(session: StreamingSession, signaling: StreamingSignalingClient? = nil) async throws {
        self.signaling = signaling
        if currentSession?.id != session.id {
            try await prepare(session: session)
        }

        if let webView {
            _ = try? await webView.evaluateJavaScript("window.xstreamingNativePlayer?.start?.()")
        }
    }

    public func sendControlEvent(_ event: StreamingControlEvent) async throws {
        guard case let .button(button, _) = event else {
            return
        }

        let buttonName = button.rawValue
        let script = "window.xstreamingNativePlayer?.pressButton?.(\(Self.javascriptString(buttonName)))"
        _ = try? await webView?.evaluateJavaScript(script)
    }

    public func stop() async {
        _ = try? await webView?.evaluateJavaScript("window.xstreamingNativePlayer?.stop?.()")
        signaling = nil
        currentSession = nil
        currentURL = nil
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

        let script = "window.xstreamingNativePlayer?.setIceCandidates?.(\(Self.javascriptJSON(remoteCandidates)))"
        _ = try? await webView?.evaluateJavaScript(script)
    }

    private static func makeICECandidate(_ dictionary: [String: Any]) -> StreamingICECandidate? {
        guard let candidate = dictionary["candidate"] as? String else {
            return nil
        }

        return StreamingICECandidate(
            messageType: dictionary["messageType"] as? String ?? "iceCandidate",
            candidate: candidate,
            sdpMid: dictionary["sdpMid"] as? String,
            sdpMLineIndex: dictionary["sdpMLineIndex"] as? String
        )
    }

    private static func javascriptString(_ value: String) -> String {
        let data = try? JSONEncoder().encode(value)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }

    private static func javascriptJSON(_ candidates: [StreamingICECandidate]) -> String {
        let values = candidates.map { candidate in
            [
                "candidate": candidate.candidate,
                "sdpMid": candidate.sdpMid ?? "0",
                "sdpMLineIndex": candidate.sdpMLineIndex ?? "0"
            ]
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
