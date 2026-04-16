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
        let result = try await repository.restoreSession(from: tokens)
        if result.authState.isSignedIn {
            try tokenStore.save(result.tokens)
        }
        return result.authState
    }

    public func beginInteractiveSignIn() async throws -> DeviceCodeChallenge {
        try await repository.beginInteractiveSignIn()
    }

    public func completeInteractiveSignIn(using challenge: DeviceCodeChallenge) async throws -> AuthState {
        let result = try await repository.completeInteractiveSignIn(using: challenge)
        try tokenStore.save(result.tokens)
        return result.authState
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
