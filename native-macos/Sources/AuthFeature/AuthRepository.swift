import Foundation
import PersistenceKit
import SharedDomain

public protocol AuthRepository: Sendable {
    func restoreSession(from tokens: StoredTokens?) async throws -> AuthState
    func signOut() async throws
}

public struct DefaultAuthRepository: AuthRepository {
    public init() {}

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

    public func signOut() async throws {}
}

public struct PreviewAuthRepository: AuthRepository {
    private let state: AuthState

    public init(state: AuthState) {
        self.state = state
    }

    public func restoreSession(from tokens: StoredTokens?) async throws -> AuthState {
        state
    }

    public func signOut() async throws {}
}
