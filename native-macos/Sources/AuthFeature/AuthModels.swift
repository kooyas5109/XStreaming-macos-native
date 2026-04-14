import Foundation
import PersistenceKit
import SharedDomain

public struct DeviceCodeChallenge: Equatable, Sendable {
    public let userCode: String
    public let verificationURL: String
    public let message: String
    public let expiresInSeconds: Int

    public init(
        userCode: String,
        verificationURL: String,
        message: String,
        expiresInSeconds: Int
    ) {
        self.userCode = userCode
        self.verificationURL = verificationURL
        self.message = message
        self.expiresInSeconds = expiresInSeconds
    }
}

public struct AuthSignInResult: Equatable, Sendable {
    public let authState: AuthState
    public let tokens: StoredTokens

    public init(authState: AuthState, tokens: StoredTokens) {
        self.authState = authState
        self.tokens = tokens
    }
}

public struct AuthViewState: Equatable, Sendable {
    public var authState: AuthState
    public var deviceCodeChallenge: DeviceCodeChallenge?
    public var errorMessage: String?

    public init(
        authState: AuthState = .signedOut,
        deviceCodeChallenge: DeviceCodeChallenge? = nil,
        errorMessage: String? = nil
    ) {
        self.authState = authState
        self.deviceCodeChallenge = deviceCodeChallenge
        self.errorMessage = errorMessage
    }
}
