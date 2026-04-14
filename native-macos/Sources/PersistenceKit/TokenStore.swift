import Foundation
import Security

public struct StoredTokens: Codable, Equatable, Sendable {
    public let authToken: String?
    public let refreshToken: String?
    public let webToken: String?
    public let xHomeStreamingToken: String?
    public let xCloudStreamingToken: String?

    public init(
        authToken: String? = nil,
        refreshToken: String? = nil,
        webToken: String? = nil,
        xHomeStreamingToken: String? = nil,
        xCloudStreamingToken: String? = nil
    ) {
        self.authToken = authToken
        self.refreshToken = refreshToken
        self.webToken = webToken
        self.xHomeStreamingToken = xHomeStreamingToken
        self.xCloudStreamingToken = xCloudStreamingToken
    }
}

public protocol TokenStoreProtocol: Sendable {
    func load() throws -> StoredTokens?
    func save(_ tokens: StoredTokens) throws
    func clear() throws
}

public enum TokenStoreError: Error, Equatable {
    case unexpectedStatus(OSStatus)
}

public final class KeychainTokenStore: TokenStoreProtocol, @unchecked Sendable {
    private let service: String
    private let account: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        service: String = "com.kooyas5109.XStreamingMacNative",
        account: String = "tokens"
    ) {
        self.service = service
        self.account = account
    }

    public func load() throws -> StoredTokens? {
        let query = baseQuery().merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw TokenStoreError.unexpectedStatus(status)
        }

        guard let data = item as? Data else {
            return nil
        }

        return try decoder.decode(StoredTokens.self, from: data)
    }

    public func save(_ tokens: StoredTokens) throws {
        let data = try encoder.encode(tokens)
        let query = baseQuery()
        let attributes = [kSecValueData as String: data]
        let status = SecItemCopyMatching(query as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw TokenStoreError.unexpectedStatus(updateStatus)
            }
        case errSecItemNotFound:
            var insertQuery = query
            insertQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw TokenStoreError.unexpectedStatus(addStatus)
            }
        default:
            throw TokenStoreError.unexpectedStatus(status)
        }
    }

    public func clear() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

public final class InMemoryTokenStore: TokenStoreProtocol, @unchecked Sendable {
    private var tokens: StoredTokens?

    public init(initialValue: StoredTokens? = nil) {
        self.tokens = initialValue
    }

    public func load() throws -> StoredTokens? {
        tokens
    }

    public func save(_ tokens: StoredTokens) throws {
        self.tokens = tokens
    }

    public func clear() throws {
        tokens = nil
    }
}
