import PersistenceKit
import Foundation
import NetworkingKit
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

@Test
func liveCatalogRepositoryLoadsCloudTitleIDsFromStreamingService() async throws {
    let tokenStore = InMemoryTokenStore()
    try tokenStore.save(
        StoredTokens(
            xCloudStreamingToken: "cloud-token",
            xCloudBaseURI: "https://cloud.example.com"
        )
    )
    let session = MockURLSession(responses: [
        MockURLSession.Response(
            body: """
            {
              "results": [
                {
                  "titleId": "9N123ABC",
                  "details": {
                    "productId": "9P123PRODUCT",
                    "xboxTitleId": 12345,
                    "supportedInputTypes": ["controller", "mouseAndKeyboard"],
                    "supportsInAppPurchases": true
                  }
                }
              ]
            }
            """
        ),
        MockURLSession.Response(statusCode: 500, body: "{}")
    ])
    let repository = LiveCatalogRepository(
        tokenStore: tokenStore,
        httpClient: HTTPClient(session: session)
    )

    let titles = try await repository.fetchTitles()

    #expect(titles.count == 1)
    #expect(titles[0].titleID == "9N123ABC")
    #expect(titles[0].productID == "9P123PRODUCT")
    #expect(titles[0].supportedInputTypes == [.controller, .mouseAndKeyboard])
    #expect(session.requests.first?.url?.absoluteString == "https://cloud.example.com/v2/titles")
    #expect(session.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer cloud-token")
}

private final class MockURLSession: URLSessionProviding, @unchecked Sendable {
    struct Response {
        let statusCode: Int
        let body: String

        init(statusCode: Int = 200, body: String) {
            self.statusCode = statusCode
            self.body = body
        }
    }

    private var responses: [Response]
    private(set) var requests: [URLRequest] = []

    init(responses: [Response]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let response = responses.isEmpty ? Response(statusCode: 500, body: "{}") : responses.removeFirst()
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(response.body.utf8), httpResponse)
    }
}
