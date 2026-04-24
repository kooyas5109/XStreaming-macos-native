import SwiftUI
import SupportKit
import WebKit

public struct StreamingWebView: NSViewRepresentable {
    private let engine: WebViewStreamingEngine
    private let onKeyEvent: (@MainActor (NSEvent) -> Bool)?
    private let onMouseButtonEvent: (@MainActor (NSEvent, Bool) -> Bool)?
    private let onMouseMoveEvent: (@MainActor (NSEvent) -> Bool)?
    private let onMouseWheelEvent: (@MainActor (NSEvent) -> Bool)?

    public init(
        engine: WebViewStreamingEngine,
        onKeyEvent: (@MainActor (NSEvent) -> Bool)? = nil,
        onMouseButtonEvent: (@MainActor (NSEvent, Bool) -> Bool)? = nil,
        onMouseMoveEvent: (@MainActor (NSEvent) -> Bool)? = nil,
        onMouseWheelEvent: (@MainActor (NSEvent) -> Bool)? = nil
    ) {
        self.engine = engine
        self.onKeyEvent = onKeyEvent
        self.onMouseButtonEvent = onMouseButtonEvent
        self.onMouseMoveEvent = onMouseMoveEvent
        self.onMouseWheelEvent = onMouseWheelEvent
    }

    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = KeyboardCapturingWebView(frame: .zero, configuration: configuration)
        webView.onKeyEvent = { event in
            onKeyEvent?(event) ?? false
        }
        webView.onMouseButtonEvent = { event, pressed in
            onMouseButtonEvent?(event, pressed) ?? false
        }
        webView.onMouseMoveEvent = { event in
            onMouseMoveEvent?(event) ?? false
        }
        webView.onMouseWheelEvent = { event in
            onMouseWheelEvent?(event) ?? false
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
        (webView as? KeyboardCapturingWebView)?.onMouseButtonEvent = { event, pressed in
            onMouseButtonEvent?(event, pressed) ?? false
        }
        (webView as? KeyboardCapturingWebView)?.onMouseMoveEvent = { event in
            onMouseMoveEvent?(event) ?? false
        }
        (webView as? KeyboardCapturingWebView)?.onMouseWheelEvent = { event in
            onMouseWheelEvent?(event) ?? false
        }
        DispatchQueue.main.async {
            webView.window?.makeFirstResponder(webView)
        }
    }
}

private final class KeyboardCapturingWebView: WKWebView {
    var onKeyEvent: ((NSEvent) -> Bool)?
    var onMouseButtonEvent: ((NSEvent, Bool) -> Bool)?
    var onMouseMoveEvent: ((NSEvent) -> Bool)?
    var onMouseWheelEvent: ((NSEvent) -> Bool)?
    private let logger = AppLogger(category: "WebRTC")
    private var trackingAreaReference: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        logger.info("Streaming WebView becomeFirstResponder=\(became ? "1" : "0")")
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        logger.info("Streaming WebView resignFirstResponder=\(resigned ? "1" : "0")")
        return resigned
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.window?.makeFirstResponder(nil)
            self.window?.makeFirstResponder(self)
            self.logger.info("Streaming WebView requested first responder")
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaReference = trackingArea
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(nil)
        window?.makeFirstResponder(self)
        logger.info("Streaming WebView mouse focus requested")
        if onMouseButtonEvent?(event, true) == true {
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if onMouseButtonEvent?(event, false) == true {
            return
        }
        super.mouseUp(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(nil)
        window?.makeFirstResponder(self)
        if onMouseButtonEvent?(event, true) == true {
            return
        }
        super.rightMouseDown(with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        if onMouseButtonEvent?(event, false) == true {
            return
        }
        super.rightMouseUp(with: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(nil)
        window?.makeFirstResponder(self)
        if onMouseButtonEvent?(event, true) == true {
            return
        }
        super.otherMouseDown(with: event)
    }

    override func otherMouseUp(with event: NSEvent) {
        if onMouseButtonEvent?(event, false) == true {
            return
        }
        super.otherMouseUp(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        if onMouseMoveEvent?(event) == true {
            return
        }
        super.mouseMoved(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if onMouseMoveEvent?(event) == true {
            return
        }
        super.mouseDragged(with: event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        if onMouseMoveEvent?(event) == true {
            return
        }
        super.rightMouseDragged(with: event)
    }

    override func otherMouseDragged(with event: NSEvent) {
        if onMouseMoveEvent?(event) == true {
            return
        }
        super.otherMouseDragged(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        if onMouseWheelEvent?(event) == true {
            return
        }
        super.scrollWheel(with: event)
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
