import SwiftUI
import WebKit

public struct StreamingWebView: NSViewRepresentable {
    private let engine: WebViewStreamingEngine

    public init(engine: WebViewStreamingEngine) {
        self.engine = engine
    }

    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsMagnification = false
        webView.setValue(false, forKey: "drawsBackground")
        engine.attach(webView: webView)
        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {}
}
