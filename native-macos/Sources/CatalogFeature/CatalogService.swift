import PersistenceKit
import SharedDomain

public struct CatalogLoadResult: Equatable, Sendable {
    public let cachedTitles: [CatalogTitle]
    public let titles: [CatalogTitle]
    public let recentTitles: [CatalogTitle]
    public let newTitles: [CatalogTitle]
}

public final class CatalogService: @unchecked Sendable {
    private let repository: CatalogRepository
    private let cacheStore: CacheStoreProtocol
    private let cacheKey = "catalog.titles"

    public init(
        repository: CatalogRepository,
        cacheStore: CacheStoreProtocol
    ) {
        self.repository = repository
        self.cacheStore = cacheStore
    }

    public func loadCatalog() async throws -> CatalogLoadResult {
        let cachedEnvelope = try cacheStore.load([CatalogTitle].self, forKey: cacheKey)
        let cachedTitles = cachedEnvelope?.value ?? []

        async let titlesTask = repository.fetchTitles()
        async let recentTask = repository.fetchRecentTitles()
        async let newTask = repository.fetchNewTitles()

        let titles = try await titlesTask
        let recentTitles = try await recentTask
        let newTitles = try await newTask

        try cacheStore.save(CacheEnvelope(value: titles), forKey: cacheKey)

        return CatalogLoadResult(
            cachedTitles: cachedTitles,
            titles: titles,
            recentTitles: recentTitles,
            newTitles: newTitles
        )
    }

    public static func preview() -> CatalogService {
        let titles = CatalogFixtures.allTitles
        return CatalogService(
            repository: PreviewCatalogRepository(
                titles: titles,
                recentTitles: [titles[0]],
                newTitles: [titles[1]]
            ),
            cacheStore: InMemoryCacheStore()
        )
    }

    public static func live(tokenStore: TokenStoreProtocol) -> CatalogService {
        CatalogService(
            repository: LiveCatalogRepository(tokenStore: tokenStore),
            cacheStore: InMemoryCacheStore()
        )
    }
}

enum CatalogFixtures {
    static let allTitles: [CatalogTitle] = [
        CatalogTitle(
            titleID: "title-1",
            productID: "product-1",
            xboxTitleID: 1001,
            productTitle: "Forza Horizon",
            publisherName: "Xbox Game Studios",
            supportedInputTypes: [.controller]
        ),
        CatalogTitle(
            titleID: "title-2",
            productID: "product-2",
            xboxTitleID: 1002,
            productTitle: "Halo Infinite",
            publisherName: "Xbox Game Studios",
            supportedInputTypes: [.controller, .mouseAndKeyboard]
        )
    ]
}
