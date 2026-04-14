import SharedDomain

public protocol CatalogRepository: Sendable {
    func fetchTitles() async throws -> [CatalogTitle]
    func fetchRecentTitles() async throws -> [CatalogTitle]
    func fetchNewTitles() async throws -> [CatalogTitle]
}

public struct PreviewCatalogRepository: CatalogRepository {
    private let titles: [CatalogTitle]
    private let recentTitles: [CatalogTitle]
    private let newTitles: [CatalogTitle]

    public init(
        titles: [CatalogTitle],
        recentTitles: [CatalogTitle],
        newTitles: [CatalogTitle]
    ) {
        self.titles = titles
        self.recentTitles = recentTitles
        self.newTitles = newTitles
    }

    public func fetchTitles() async throws -> [CatalogTitle] {
        titles
    }

    public func fetchRecentTitles() async throws -> [CatalogTitle] {
        recentTitles
    }

    public func fetchNewTitles() async throws -> [CatalogTitle] {
        newTitles
    }
}
