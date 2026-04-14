import PersistenceKit
import Testing
@testable import CatalogFeature

@Test
func catalogServiceLoadsCachedTitlesBeforeRefreshingRemoteData() async throws {
    let cacheStore = InMemoryCacheStore()
    try cacheStore.save(
        CacheEnvelope(value: [
            CatalogFixtures.allTitles[0]
        ]),
        forKey: "catalog.titles"
    )

    let service = CatalogService(
        repository: PreviewCatalogRepository(
            titles: CatalogFixtures.allTitles,
            recentTitles: [CatalogFixtures.allTitles[0]],
            newTitles: [CatalogFixtures.allTitles[1]]
        ),
        cacheStore: cacheStore
    )

    let result = try await service.loadCatalog()
    #expect(result.cachedTitles.count == 1)
    #expect(result.titles.count == 2)
    #expect(result.recentTitles.count == 1)
    #expect(result.newTitles.count == 1)
}
