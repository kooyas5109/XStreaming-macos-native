import SwiftUI

public struct RootView: View {
    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        ContentUnavailableView(
            "XStreaming macOS Native",
            systemImage: "macwindow.on.rectangle",
            description: Text("Native app shell bootstrap complete.")
        )
        .frame(minWidth: 960, minHeight: 600)
        .task {
            environment.logger.info("RootView loaded with route: \(String(describing: environment.router.currentRoute))")
        }
    }
}
