import SharedDomain

public protocol AchievementRepository: Sendable {
    func fetchAchievements(for titleID: String) async throws -> [String]
}

public struct PreviewAchievementRepository: AchievementRepository {
    public init() {}

    public func fetchAchievements(for titleID: String) async throws -> [String] {
        ["Achievement preview for \(titleID)"]
    }
}
