import Foundation
import PersistenceKit
import SharedDomain

public protocol AuthRepository: Sendable {
    func restoreSession(from tokens: StoredTokens?) async throws -> AuthState
    func beginInteractiveSignIn() async throws -> DeviceCodeChallenge
    func completeInteractiveSignIn(using challenge: DeviceCodeChallenge) async throws -> AuthSignInResult
    func signOut() async throws
}

public struct DefaultAuthRepository: AuthRepository {
    private let provider: any XboxAuthProviding

    public init(provider: any XboxAuthProviding = PreviewXboxAuthProvider()) {
        self.provider = provider
    }

    public func restoreSession(from tokens: StoredTokens?) async throws -> AuthState {
        guard let tokens, let authToken = tokens.authToken, authToken.isEmpty == false else {
            return .signedOut
        }

        let profile = UserProfile(
            gamertag: "Signed In User",
            gamerpicURL: nil,
            gamerscore: "",
            appLevel: 1
        )

        return AuthState(
            isSignedIn: true,
            isAuthenticating: false,
            userProfile: profile,
            statusMessage: "Restored session from stored tokens."
        )
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

    public func restoreSession(from tokens: StoredTokens?) async throws -> AuthState {
        state
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
