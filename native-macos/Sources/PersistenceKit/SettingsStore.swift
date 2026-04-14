import Foundation
import SharedDomain

public protocol SettingsStoreProtocol: Sendable {
    func load() throws -> AppSettings
    func save(_ settings: AppSettings) throws
    func reset() throws -> AppSettings
}

public final class UserDefaultsSettingsStore: SettingsStoreProtocol, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(userDefaults: UserDefaults = .standard, key: String = "app.settings") {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func load() throws -> AppSettings {
        guard let data = userDefaults.data(forKey: key) else {
            return .defaults
        }

        do {
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            return .defaults
        }
    }

    public func save(_ settings: AppSettings) throws {
        let data = try encoder.encode(settings)
        userDefaults.set(data, forKey: key)
    }

    public func reset() throws -> AppSettings {
        let defaults = AppSettings.defaults
        try save(defaults)
        return defaults
    }
}

public final class InMemorySettingsStore: SettingsStoreProtocol, @unchecked Sendable {
    private var currentSettings: AppSettings?

    public init(initialValue: AppSettings? = nil) {
        self.currentSettings = initialValue
    }

    public func load() throws -> AppSettings {
        currentSettings ?? .defaults
    }

    public func save(_ settings: AppSettings) throws {
        currentSettings = settings
    }

    public func reset() throws -> AppSettings {
        currentSettings = .defaults
        return .defaults
    }
}
