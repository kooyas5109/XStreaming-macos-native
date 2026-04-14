import Foundation

public protocol AuthRepositoryProtocol: Sendable {}

public protocol ConsoleRepositoryProtocol: Sendable {
    func fetchConsoles() async throws -> [ConsoleDevice]
}

public protocol CatalogRepositoryProtocol: Sendable {
    func fetchTitles() async throws -> [CatalogTitle]
}

public protocol StreamingRepositoryProtocol: Sendable {
    func createSession(kind: StreamingKind, targetID: String) async throws -> StreamingSession
}

public protocol SettingsRepositoryProtocol: Sendable {
    func loadSettings() async throws -> AppSettings
}
