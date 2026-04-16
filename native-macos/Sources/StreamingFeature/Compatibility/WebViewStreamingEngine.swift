import Foundation
import WebKit
import SharedDomain

public enum WebViewStreamingEngineError: Error, Equatable, Sendable {
    case invalidSessionURL
    case bridgeScriptUnavailable
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

    private let configuration: WebViewStreamingConfiguration
    private weak var webView: WKWebView?

    public init(
        configuration: WebViewStreamingConfiguration,
        bridgeScript: String
    ) {
        self.configuration = configuration
        self.bridgeScript = bridgeScript
    }

    public convenience init(configuration: WebViewStreamingConfiguration) throws {
        try self.init(
            configuration: configuration,
            bridgeScript: BridgeScriptLoader.load()
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
        webView.configuration.userContentController.addUserScript(userScript)
    }

    public func prepare(session: StreamingSession) async throws {
        let url = try makeStreamURL(for: session)
        currentSession = session
        currentURL = url

        if let webView {
            webView.load(URLRequest(url: url))
        }
    }

    public func start(session: StreamingSession, signaling: StreamingSignalingClient? = nil) async throws {
        if currentSession?.id != session.id {
            try await prepare(session: session)
        }

        if let webView {
            _ = try? await webView.evaluateJavaScript("window.nativeStreamingBridge?.notifyNativeReady?.()")
        }
    }

    public func sendControlEvent(_ event: StreamingControlEvent) async {}

    public func stop() async {
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
}

enum BridgeScriptLoader {
    static func load(bundle: Bundle = .module) throws -> String {
        guard let url = bundle.url(forResource: "BridgeScript", withExtension: "js") else {
            throw WebViewStreamingEngineError.bridgeScriptUnavailable
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
