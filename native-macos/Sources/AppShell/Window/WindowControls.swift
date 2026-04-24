import AppKit
import SupportKit

@MainActor
enum WindowControls {
    private static let logger = AppLogger(category: "WebRTC")

    static func toggleFullscreen() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        window.toggleFullScreen(nil)
    }

    static func enterFullscreenIfNeeded() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        guard window.styleMask.contains(.fullScreen) == false else { return }
        window.toggleFullScreen(nil)
    }

    static func focusActiveWindow() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            logger.info("Window focus request skipped because no active window was found")
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.makeKeyAndOrderFront(nil)
        logger.info("Window focus requested for streaming window")
    }
}
