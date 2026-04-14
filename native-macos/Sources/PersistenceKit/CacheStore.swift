import Foundation

public struct CacheEnvelope<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let updatedAt: Date
    public let value: Value

    public init(schemaVersion: Int = 1, updatedAt: Date = Date(), value: Value) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.value = value
    }
}

public protocol CacheStoreProtocol: Sendable {
    func load<Value: Codable & Equatable & Sendable>(_ type: Value.Type, forKey key: String) throws -> CacheEnvelope<Value>?
    func save<Value: Codable & Equatable & Sendable>(_ envelope: CacheEnvelope<Value>, forKey key: String) throws
    func clear(forKey key: String) throws
}

public final class FileCacheStore: CacheStoreProtocol, @unchecked Sendable {
    private let directoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager

    public init(
        directoryURL: URL,
        fileManager: FileManager = .default
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
    }

    public func load<Value>(_ type: Value.Type, forKey key: String) throws -> CacheEnvelope<Value>? where Value: Codable & Equatable & Sendable {
        let url = fileURL(forKey: key)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(CacheEnvelope<Value>.self, from: data)
    }

    public func save<Value>(_ envelope: CacheEnvelope<Value>, forKey key: String) throws where Value: Codable & Equatable & Sendable {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let url = fileURL(forKey: key)
        let data = try encoder.encode(envelope)
        try data.write(to: url, options: .atomic)
    }

    public func clear(forKey key: String) throws {
        let url = fileURL(forKey: key)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
    }

    private func fileURL(forKey key: String) -> URL {
        directoryURL.appendingPathComponent("\(key).json")
    }
}

public final class InMemoryCacheStore: CacheStoreProtocol, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {}

    public func load<Value>(_ type: Value.Type, forKey key: String) throws -> CacheEnvelope<Value>? where Value: Codable & Equatable & Sendable {
        guard let data = storage[key] else {
            return nil
        }
        return try decoder.decode(CacheEnvelope<Value>.self, from: data)
    }

    public func save<Value>(_ envelope: CacheEnvelope<Value>, forKey key: String) throws where Value: Codable & Equatable & Sendable {
        storage[key] = try encoder.encode(envelope)
    }

    public func clear(forKey key: String) throws {
        storage[key] = nil
    }
}
