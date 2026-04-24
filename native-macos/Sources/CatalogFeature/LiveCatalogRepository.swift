import Foundation
import NetworkingKit
import PersistenceKit
import SharedDomain

public enum LiveCatalogRepositoryError: Error, Equatable {
    case missingCloudToken
    case invalidCloudBaseURI(String)
    case requestFailed(stage: String, statusCode: Int, bodySnippet: String)
}

public final class LiveCatalogRepository: CatalogRepository, @unchecked Sendable {
    private let tokenStore: TokenStoreProtocol
    private let httpClient: HTTPClient
    private let defaultCloudBaseURI: String
    private let catalogBaseURL = URL(string: "https://catalog.gamepass.com")!

    public init(
        tokenStore: TokenStoreProtocol,
        httpClient: HTTPClient = HTTPClient(),
        defaultCloudBaseURI: String = "https://xgpuweb.gssv-play-prod.xboxlive.com"
    ) {
        self.tokenStore = tokenStore
        self.httpClient = httpClient
        self.defaultCloudBaseURI = defaultCloudBaseURI
    }

    public func fetchTitles() async throws -> [CatalogTitle] {
        let titles = try await fetchCloudTitles(path: "/v2/titles")
        return await enrichTitles(titles)
    }

    public func fetchRecentTitles() async throws -> [CatalogTitle] {
        let titles = try await fetchCloudTitles(
            path: "/v2/titles/mru",
            queryItems: [URLQueryItem(name: "mr", value: "25")]
        )
        return await enrichTitles(titles)
    }

    public func fetchNewTitles() async throws -> [CatalogTitle] {
        let titles = try await fetchTitles()
        return Array(titles.prefix(25))
    }

    private func fetchCloudTitles(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> [CatalogTitle] {
        let context = try loadContext()
        let request = try RequestBuilder.make(
            baseURL: context.baseURL,
            path: path,
            queryItems: queryItems,
            token: context.token
        )
        let response = try await httpClient.send(request)
        try validate(response, stage: path)
        let payload = try JSONDecoder().decode(CloudTitlesResponse.self, from: response.data)
        return payload.results.compactMap { $0.catalogTitle }
    }

    private func enrichTitles(_ titles: [CatalogTitle]) async -> [CatalogTitle] {
        let productIDs = titles.map(\.productID).filter { $0.isEmpty == false }
        guard productIDs.isEmpty == false else {
            return titles
        }

        do {
            let products = try await fetchCatalogProducts(productIDs: productIDs)
            return titles.map { title in
                guard let product = products[title.productID] else {
                    return title
                }
                return title.merging(product: product)
            }
        } catch {
            return titles
        }
    }

    private func fetchCatalogProducts(productIDs: [String]) async throws -> [String: GamePassProduct] {
        let uniqueProductIDs = Array(Set(productIDs))
        let body = try JSONEncoder().encode(GamePassProductRequest(products: uniqueProductIDs))
        let request = try RequestBuilder.make(
            baseURL: catalogBaseURL,
            path: "/v3/products",
            method: .post,
            queryItems: [
                URLQueryItem(name: "market", value: "US"),
                URLQueryItem(name: "language", value: "zh-TW"),
                URLQueryItem(name: "hydration", value: "RemoteLowJade0")
            ],
            headers: [
                "Accept": "application/json",
                "ms-cv": "0",
                "calling-app-name": "Xbox Cloud Gaming Web",
                "calling-app-version": "24.17.63"
            ],
            body: body
        )
        let response = try await httpClient.send(request)
        try validate(response, stage: "catalog products")
        let payload = try JSONDecoder().decode(GamePassProductResponse.self, from: response.data)
        return payload.products
    }

    private func loadContext() throws -> (token: String, baseURL: URL) {
        let tokens = try tokenStore.load()
        guard let token = tokens?.xCloudStreamingToken, token.isEmpty == false else {
            throw LiveCatalogRepositoryError.missingCloudToken
        }

        let baseURI = tokens?.xCloudBaseURI ?? defaultCloudBaseURI
        guard let baseURL = URL(string: baseURI) else {
            throw LiveCatalogRepositoryError.invalidCloudBaseURI(baseURI)
        }

        return (token, baseURL)
    }

    private func validate(_ response: HTTPResponse, stage: String) throws {
        guard (200..<300).contains(response.response.statusCode) else {
            throw LiveCatalogRepositoryError.requestFailed(
                stage: stage,
                statusCode: response.response.statusCode,
                bodySnippet: Self.snippet(response.data)
            )
        }
    }

    private static func snippet(_ data: Data, limit: Int = 500) -> String {
        String(decoding: data.prefix(limit), as: UTF8.self)
    }
}

private struct CloudTitlesResponse: Decodable {
    let results: [CloudTitle]
}

private struct CloudTitle: Decodable {
    let titleID: String?
    let titleId: String?
    let productID: String?
    let productId: String?
    let titleName: String?
    let name: String?
    let details: CloudTitleDetails?

    var catalogTitle: CatalogTitle? {
        let resolvedTitleID = titleID ?? titleId ?? details?.titleID ?? details?.titleId
        let resolvedProductID = productID ?? productId ?? details?.productID ?? details?.productId
        guard let titleID = resolvedTitleID, titleID.isEmpty == false else {
            return nil
        }

        let productID = resolvedProductID ?? titleID
        return CatalogTitle(
            titleID: titleID,
            productID: productID,
            xboxTitleID: details?.xboxTitleID ?? details?.xboxTitleId,
            productTitle: titleName ?? name ?? details?.productTitle ?? productID,
            publisherName: details?.publisherName ?? "",
            supportedInputTypes: details?.supportedInputTypes?.compactMap(Self.inputType) ?? [],
            supportsInAppPurchases: details?.supportsInAppPurchases ?? false
        )
    }

    private static func inputType(_ value: String) -> InputType? {
        switch value.lowercased() {
        case "controller":
            return .controller
        case "mouseandkeyboard", "mousekeyboard":
            return .mouseAndKeyboard
        case "touch":
            return .touch
        default:
            return nil
        }
    }
}

private struct CloudTitleDetails: Decodable {
    let titleID: String?
    let titleId: String?
    let productID: String?
    let productId: String?
    let xboxTitleID: Int?
    let xboxTitleId: Int?
    let productTitle: String?
    let publisherName: String?
    let supportedInputTypes: [String]?
    let supportsInAppPurchases: Bool?
}

private struct GamePassProductRequest: Encodable {
    let products: [String]

    enum CodingKeys: String, CodingKey {
        case products = "Products"
    }
}

private struct GamePassProductResponse: Decodable {
    let products: [String: GamePassProduct]

    enum CodingKeys: String, CodingKey {
        case products = "Products"
    }
}

private struct GamePassProduct: Decodable {
    let productTitle: String?
    let publisherName: String?
    let localizedProperties: [LocalizedProperty]?

    enum CodingKeys: String, CodingKey {
        case productTitle = "ProductTitle"
        case publisherName = "PublisherName"
        case localizedProperties = "LocalizedProperties"
    }

    var displayTitle: String? {
        productTitle ?? localizedProperties?.first?.productTitle
    }

    var displayPublisher: String? {
        publisherName ?? localizedProperties?.first?.publisherName
    }
}

private struct LocalizedProperty: Decodable {
    let productTitle: String?
    let publisherName: String?

    enum CodingKeys: String, CodingKey {
        case productTitle = "ProductTitle"
        case publisherName = "PublisherName"
    }
}

private extension CatalogTitle {
    func merging(product: GamePassProduct) -> CatalogTitle {
        CatalogTitle(
            titleID: titleID,
            productID: productID,
            xboxTitleID: xboxTitleID,
            productTitle: product.displayTitle ?? productTitle,
            publisherName: product.displayPublisher ?? publisherName,
            imageTileURL: imageTileURL,
            imagePosterURL: imagePosterURL,
            supportedInputTypes: supportedInputTypes,
            supportsInAppPurchases: supportsInAppPurchases
        )
    }
}
