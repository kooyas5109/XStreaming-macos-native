import Foundation

public enum InputType: String, Codable, Equatable, Sendable, CaseIterable {
    case controller
    case mouseAndKeyboard
    case touch
    case unknown
}

public struct CatalogTitle: Codable, Equatable, Sendable {
    public let titleID: String
    public let productID: String
    public let xboxTitleID: Int?
    public let productTitle: String
    public let publisherName: String
    public let imageTileURL: URL?
    public let imagePosterURL: URL?
    public let supportedInputTypes: [InputType]
    public let supportsInAppPurchases: Bool

    public init(
        titleID: String,
        productID: String,
        xboxTitleID: Int? = nil,
        productTitle: String,
        publisherName: String = "",
        imageTileURL: URL? = nil,
        imagePosterURL: URL? = nil,
        supportedInputTypes: [InputType] = [],
        supportsInAppPurchases: Bool = false
    ) {
        self.titleID = titleID
        self.productID = productID
        self.xboxTitleID = xboxTitleID
        self.productTitle = productTitle
        self.publisherName = publisherName
        self.imageTileURL = imageTileURL
        self.imagePosterURL = imagePosterURL
        self.supportedInputTypes = supportedInputTypes
        self.supportsInAppPurchases = supportsInAppPurchases
    }
}
