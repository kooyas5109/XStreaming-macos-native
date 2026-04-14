import Foundation
import PersistenceKit
import SharedDomain

public final class AuthService: @unchecked Sendable {
    private let repository: AuthRepository
    private let tokenStore: TokenStoreProtocol

    public init(
        repository: AuthRepository,
        tokenStore: TokenStoreProtocol
    ) {
        self.repository = repository
        self.tokenStore = tokenStore
    }

    public func restoreSession() async throws -> AuthState {
        let tokens = try tokenStore.load()
        return try await repository.restoreSession(from: tokens)
    }

    public func signOut() async throws -> AuthState {
        try await repository.signOut()
        try tokenStore.clear()
        return .signedOut
    }

    public static func previewSignedOut() -> AuthService {
        AuthService(
            repository: PreviewAuthRepository(state: .signedOut),
            tokenStore: InMemoryTokenStore()
        )
    }
}
