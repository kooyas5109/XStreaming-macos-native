import AppShell
import SwiftUI

@main
struct XStreamingMacApp: App {
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
