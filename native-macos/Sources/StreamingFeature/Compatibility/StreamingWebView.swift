import SwiftUI
import SupportKit
import WebKit

public struct StreamingWebView: NSViewRepresentable {
    private let engine: WebViewStreamingEngine
    private let onKeyEvent: (@MainActor (NSEvent) -> Bool)?

    public init(
        engine: WebViewStreamingEngine,
        onKeyEvent: (@MainActor (NSEvent) -> Bool)? = nil
    ) {
        self.engine = engine
        self.onKeyEvent = onKeyEvent
    }

    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = KeyboardCapturingWebView(frame: .zero, configuration: configuration)
        webView.onKeyEvent = { event in
            onKeyEvent?(event) ?? false
        }
        webView.allowsMagnification = false
        webView.setValue(false, forKey: "drawsBackground")
        engine.attach(webView: webView)
        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        (webView as? KeyboardCapturingWebView)?.onKeyEvent = { event in
            onKeyEvent?(event) ?? false
        }
        DispatchQueue.main.async {
            webView.window?.makeFirstResponder(webView)
        }
    }
}

private final class KeyboardCapturingWebView: WKWebView {
    var onKeyEvent: ((NSEvent) -> Bool)?
    private let logger = AppLogger(category: "WebRTC")

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.window?.makeFirstResponder(self)
            self.logger.info("Streaming WebView requested first responder")
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        logger.info("Streaming WebView mouse focus requested")
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        logger.info("Streaming WebView keyDown received: keyCode=\(event.keyCode)")
        if onKeyEvent?(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        logger.info("Streaming WebView keyUp received: keyCode=\(event.keyCode)")
        if onKeyEvent?(event) == true {
            return
        }
        super.keyUp(with: event)
    }
}
