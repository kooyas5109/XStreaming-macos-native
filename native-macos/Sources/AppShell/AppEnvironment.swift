import Foundation
import CatalogFeature
import ConsoleFeature
import PersistenceKit
import SettingsFeature
import StreamingFeature
import SupportKit

public struct AppEnvironment: Sendable {
    public let router: AppRouter
    public let logger: AppLogger
    public let streamCommandCenter: StreamCommandCenter
    public let consoleService: ConsoleService
    public let catalogService: CatalogService
    public let settingsStore: SettingsStoreProtocol
    public let streamingService: StreamingService
    public let streamingEngine: any StreamingEngineProtocol

    public init(
        router: AppRouter,
        logger: AppLogger,
        streamCommandCenter: StreamCommandCenter,
        consoleService: ConsoleService,
        catalogService: CatalogService,
        settingsStore: SettingsStoreProtocol,
        streamingService: StreamingService,
        streamingEngine: any StreamingEngineProtocol
    ) {
        self.router = router
        self.logger = logger
        self.streamCommandCenter = streamCommandCenter
        self.consoleService = consoleService
        self.catalogService = catalogService
        self.settingsStore = settingsStore
        self.streamingService = streamingService
        self.streamingEngine = streamingEngine
    }

    @MainActor
    public static func makePreview() -> AppEnvironment {
        let streamingEngine = NativeStreamingEngine.preview()
        let repository = PreviewStreamingRepository()
        return AppEnvironment(
            router: AppRouter(),
            logger: .preview(category: "app"),
            streamCommandCenter: StreamCommandCenter(),
            consoleService: .preview(),
            catalogService: .preview(),
            settingsStore: InMemorySettingsStore(),
            streamingService: StreamingService(
                repository: repository,
                engine: streamingEngine,
                monitor: StreamingSessionMonitor(
                    repository: repository,
                    maxAttempts: 3,
                    pollIntervalNanoseconds: 1_000_000
                )
            ),
            streamingEngine: streamingEngine
        )
    }
}
