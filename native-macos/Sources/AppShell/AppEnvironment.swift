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
    public let mouseKeyboardProfileStore: MouseKeyboardProfileStoreProtocol
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
        mouseKeyboardProfileStore: MouseKeyboardProfileStoreProtocol,
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
        self.mouseKeyboardProfileStore = mouseKeyboardProfileStore
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
        let streamingEngine: any StreamingEngineProtocol
        let repository: StreamingRepository
        let authRepository: DefaultAuthRepository
        let tokenStore: TokenStoreProtocol
        let settingsStore: SettingsStoreProtocol
        let mouseKeyboardProfileStore: MouseKeyboardProfileStoreProtocol

        switch mode {
        case .preview:
            streamingEngine = NativeStreamingEngine.preview()
            authRepository = DefaultAuthRepository(provider: PreviewXboxAuthProvider())
            tokenStore = InMemoryTokenStore()
            repository = PreviewStreamingRepository()
            settingsStore = InMemorySettingsStore()
            mouseKeyboardProfileStore = InMemoryMouseKeyboardProfileStore()
        case .live:
            streamingEngine = try! WebViewStreamingEngine(configuration: .preview)
            authRepository = DefaultAuthRepository(provider: LiveXboxAuthProvider())
            tokenStore = KeychainTokenStore()
            repository = LiveStreamingRepository(tokenStore: tokenStore)
            settingsStore = UserDefaultsSettingsStore()
            mouseKeyboardProfileStore = UserDefaultsMouseKeyboardProfileStore()
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
            catalogService: mode == .live ? .live(tokenStore: tokenStore) : .preview(),
            settingsStore: settingsStore,
            mouseKeyboardProfileStore: mouseKeyboardProfileStore,
            streamingService: StreamingService(
                repository: repository,
                engine: streamingEngine,
                monitor: StreamingSessionMonitor(
                    repository: repository,
                    maxAttempts: mode == .live ? 30 : 3,
                    pollIntervalNanoseconds: mode == .live ? 2_000_000_000 : 1_000_000
                )
            ),
            streamingEngine: streamingEngine
        )
    }
}
