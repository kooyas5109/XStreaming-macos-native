import PersistenceKit
import SharedDomain

public struct ConsoleLoadResult: Equatable, Sendable {
    public let cached: [ConsoleDevice]
    public let remote: [ConsoleDevice]

    public init(cached: [ConsoleDevice], remote: [ConsoleDevice]) {
        self.cached = cached
        self.remote = remote
    }
}

public final class ConsoleService: @unchecked Sendable {
    private let repository: ConsoleRepository
    private let cacheStore: CacheStoreProtocol
    private let cacheKey = "consoles"

    public init(
        repository: ConsoleRepository,
        cacheStore: CacheStoreProtocol
    ) {
        self.repository = repository
        self.cacheStore = cacheStore
    }

    public func loadConsoles() async throws -> ConsoleLoadResult {
        let cachedEnvelope = try cacheStore.load([ConsoleDevice].self, forKey: cacheKey)
        let cached = cachedEnvelope?.value ?? []

        let remote = try await repository.fetchConsoles()
        try cacheStore.save(CacheEnvelope(value: remote), forKey: cacheKey)

        return ConsoleLoadResult(cached: cached, remote: remote)
    }

    public func powerOn(consoleID: String) async throws {
        try await repository.powerOn(consoleID: consoleID)
    }

    public func powerOff(consoleID: String) async throws {
        try await repository.powerOff(consoleID: consoleID)
    }

    public func sendText(consoleID: String, text: String) async throws {
        try await repository.sendText(consoleID: consoleID, text: text)
    }

    public static func preview() -> ConsoleService {
        ConsoleService(
            repository: PreviewConsoleRepository(consoles: ConsoleFixtures.sampleConsoles),
            cacheStore: InMemoryCacheStore()
        )
    }

    public static func live(tokenStore: TokenStoreProtocol) -> ConsoleService {
        ConsoleService(
            repository: LiveConsoleRepository(tokenStore: tokenStore),
            cacheStore: InMemoryCacheStore()
        )
    }
}

enum ConsoleFixtures {
    static let sampleConsoles: [ConsoleDevice] = [
        ConsoleDevice(
            id: "console-1",
            name: "Living Room Xbox",
            locale: "en-US",
            region: "US",
            consoleType: .xboxSeriesX,
            powerState: .connectedStandby,
            remoteManagementEnabled: true,
            consoleStreamingEnabled: true
        ),
        ConsoleDevice(
            id: "console-2",
            name: "Bedroom Xbox",
            locale: "en-US",
            region: "US",
            consoleType: .xboxSeriesS,
            powerState: .off,
            remoteManagementEnabled: true,
            consoleStreamingEnabled: true
        )
    ]
}
