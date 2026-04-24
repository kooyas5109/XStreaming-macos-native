import SwiftUI
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
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if onKeyEvent?(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if onKeyEvent?(event) == true {
            return
        }
        super.keyUp(with: event)
    }
}
