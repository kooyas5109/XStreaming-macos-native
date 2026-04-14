import AppKit

@MainActor
enum WindowControls {
    static func toggleFullscreen() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        window.toggleFullScreen(nil)
    }

    static func enterFullscreenIfNeeded() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        guard window.styleMask.contains(.fullScreen) == false else { return }
        window.toggleFullScreen(nil)
    }
}
