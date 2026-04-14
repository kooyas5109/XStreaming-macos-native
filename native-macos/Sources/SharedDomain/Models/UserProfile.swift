import Foundation

public struct UserProfile: Codable, Equatable, Sendable {
    public let gamertag: String
    public let gamerpicURL: URL?
    public let gamerscore: String
    public let appLevel: Int

    public init(
        gamertag: String = "",
        gamerpicURL: URL? = nil,
        gamerscore: String = "",
        appLevel: Int = 0
    ) {
        self.gamertag = gamertag
        self.gamerpicURL = gamerpicURL
        self.gamerscore = gamerscore
        self.appLevel = appLevel
    }
}
