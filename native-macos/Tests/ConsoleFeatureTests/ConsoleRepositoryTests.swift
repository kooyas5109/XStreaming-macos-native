import PersistenceKit
import SharedDomain
import Testing
@testable import ConsoleFeature

@Test
func consoleServiceLoadsCachedThenRemoteConsoles() async throws {
    let cacheStore = InMemoryCacheStore()
    let cached = [
        ConsoleDevice(
            id: "cached-console",
            name: "Cached Xbox",
            consoleType: .xboxOne,
            powerState: .on
        )
    ]
    try cacheStore.save(CacheEnvelope(value: cached), forKey: "consoles")

    let service = ConsoleService(
        repository: PreviewConsoleRepository(consoles: ConsoleFixtures.sampleConsoles),
        cacheStore: cacheStore
    )

    let result = try await service.loadConsoles()
    #expect(result.cached.count == 1)
    #expect(result.remote.count == 2)
    #expect(result.remote.first?.name == "Living Room Xbox")
}
