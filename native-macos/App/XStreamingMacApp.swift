import AppShell
import AppKit
import SwiftUI

@main
struct XStreamingMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let environment = AppEnvironment.makeDefault()

    var body: some Scene {
        WindowGroup("XStreaming macOS Native") {
            RootView(environment: environment)
        }
        .commands {
            StreamCommands(commandCenter: environment.streamCommandCenter)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
