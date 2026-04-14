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

    public func beginInteractiveSignIn() async throws -> DeviceCodeChallenge {
        DeviceCodeChallenge(
            userCode: "ABCD-EFGH",
            verificationURL: "https://microsoft.com/devicelogin",
            message: "Enter the code at microsoft.com/devicelogin to continue sign-in.",
            expiresInSeconds: 900
        )
    }

    public func completeInteractiveSignIn(using challenge: DeviceCodeChallenge) async throws -> AuthSignInResult {
        let profile = UserProfile(
            gamertag: "Native Preview User",
            gamerpicURL: nil,
            gamerscore: "4200",
            appLevel: 2
        )
        let state = AuthState(
            isSignedIn: true,
            isAuthenticating: false,
            userProfile: profile,
            statusMessage: "Signed in through the native device code flow."
        )
        let tokens = StoredTokens(
            authToken: "native-auth-token-\(challenge.userCode)",
            webToken: "native-web-token",
            streamingToken: "native-streaming-token"
        )
        return AuthSignInResult(authState: state, tokens: tokens)
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

    public func beginInteractiveSignIn() async throws -> DeviceCodeChallenge {
        DeviceCodeChallenge(
            userCode: "WXYZ-1234",
            verificationURL: "https://microsoft.com/devicelogin",
            message: "Use this preview code to continue the native sign-in flow.",
            expiresInSeconds: 900
        )
    }

    public func completeInteractiveSignIn(using challenge: DeviceCodeChallenge) async throws -> AuthSignInResult {
        AuthSignInResult(
            authState: state,
            tokens: StoredTokens(
                authToken: "preview-auth-\(challenge.userCode)",
                webToken: "preview-web",
                streamingToken: "preview-stream"
            )
        )
    }

    public func signOut() async throws {}
}
