import Foundation
import SupportKit

public struct AppEnvironment: Sendable {
    public let router: AppRouter
    public let logger: AppLogger

    public init(router: AppRouter, logger: AppLogger) {
        self.router = router
        self.logger = logger
    }

    @MainActor
    public static func makePreview() -> AppEnvironment {
        AppEnvironment(
            router: AppRouter(),
            logger: .preview(category: "app")
        )
    }
}
