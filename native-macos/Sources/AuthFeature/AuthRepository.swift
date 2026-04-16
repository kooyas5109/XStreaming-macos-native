import Foundation
import PersistenceKit
import SharedDomain

public protocol AuthRepository: Sendable {
    func restoreSession(from tokens: StoredTokens?) async throws -> AuthSignInResult
    func beginInteractiveSignIn() async throws -> DeviceCodeChallenge
    func completeInteractiveSignIn(using challenge: DeviceCodeChallenge) async throws -> AuthSignInResult
    func signOut() async throws
}

public struct DefaultAuthRepository: AuthRepository {
    private let provider: any XboxAuthProviding

    public init(provider: any XboxAuthProviding = PreviewXboxAuthProvider()) {
        self.provider = provider
    }

    public func restoreSession(from tokens: StoredTokens?) async throws -> AuthSignInResult {
        try await provider.restoreSession(from: tokens)
    }

    public func beginInteractiveSignIn() async throws -> DeviceCodeChallenge {
        try await provider.requestDeviceCode()
    }

    public func completeInteractiveSignIn(using challenge: DeviceCodeChallenge) async throws -> AuthSignInResult {
        try await provider.completeDeviceCode(challenge: challenge)
    }

    public func signOut() async throws {}
}

public struct PreviewAuthRepository: AuthRepository {
    private let state: AuthState
    private let provider: any XboxAuthProviding

    public init(state: AuthState, provider: any XboxAuthProviding = PreviewXboxAuthProvider()) {
        self.state = state
        self.provider = provider
    }

    public func restoreSession(from tokens: StoredTokens?) async throws -> AuthSignInResult {
        AuthSignInResult(authState: state, tokens: tokens ?? StoredTokens())
    }

    public func beginInteractiveSignIn() async throws -> DeviceCodeChallenge {
        try await provider.requestDeviceCode()
    }

    public func completeInteractiveSignIn(using challenge: DeviceCodeChallenge) async throws -> AuthSignInResult {
        var result = try await provider.completeDeviceCode(challenge: challenge)
        result = AuthSignInResult(authState: state, tokens: result.tokens)
        return result
    }

    public func signOut() async throws {}
}
