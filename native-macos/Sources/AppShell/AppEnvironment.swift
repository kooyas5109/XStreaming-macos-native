import Foundation
import AuthFeature
import CatalogFeature
import ConsoleFeature
import PersistenceKit
import SettingsFeature
import StreamingFeature
import SupportKit

public struct AppEnvironment: Sendable {
    public let authMode: AuthProviderMode
    public let router: AppRouter
    public let logger: AppLogger
    public let streamCommandCenter: StreamCommandCenter
    public let authService: AuthService
    public let consoleService: ConsoleService
    public let catalogService: CatalogService
    public let settingsStore: SettingsStoreProtocol
    public let streamingService: StreamingService
    public let streamingEngine: any StreamingEngineProtocol

    public init(
        router: AppRouter,
        authMode: AuthProviderMode,
        logger: AppLogger,
        streamCommandCenter: StreamCommandCenter,
        authService: AuthService,
        consoleService: ConsoleService,
        catalogService: CatalogService,
        settingsStore: SettingsStoreProtocol,
        streamingService: StreamingService,
        streamingEngine: any StreamingEngineProtocol
    ) {
        self.authMode = authMode
        self.router = router
        self.logger = logger
        self.streamCommandCenter = streamCommandCenter
        self.authService = authService
        self.consoleService = consoleService
        self.catalogService = catalogService
        self.settingsStore = settingsStore
        self.streamingService = streamingService
        self.streamingEngine = streamingEngine
    }

    @MainActor
    public static func makePreview() -> AppEnvironment {
        make(mode: .preview)
    }

    @MainActor
    public static func makeDefault() -> AppEnvironment {
        let mode = AuthProviderMode(environmentValue: ProcessInfo.processInfo.environment["XSTREAMING_AUTH_MODE"])
        return make(mode: mode)
    }

    @MainActor
    public static func make(mode: AuthProviderMode) -> AppEnvironment {
        let streamingEngine = NativeStreamingEngine.preview()
        let repository = PreviewStreamingRepository()
        let authRepository: DefaultAuthRepository
        let tokenStore: TokenStoreProtocol

        switch mode {
        case .preview:
            authRepository = DefaultAuthRepository(provider: PreviewXboxAuthProvider())
            tokenStore = InMemoryTokenStore()
        case .live:
            authRepository = DefaultAuthRepository(provider: LiveXboxAuthProvider())
            tokenStore = KeychainTokenStore()
        }

        return AppEnvironment(
            router: AppRouter(),
            authMode: mode,
            logger: .preview(category: "app"),
            streamCommandCenter: StreamCommandCenter(),
            authService: AuthService(
                repository: authRepository,
                tokenStore: tokenStore
            ),
            consoleService: mode == .live ? .live(tokenStore: tokenStore) : .preview(),
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
