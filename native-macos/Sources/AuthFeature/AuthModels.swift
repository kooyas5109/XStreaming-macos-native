import Foundation
import PersistenceKit
import SharedDomain

public struct DeviceCodeChallenge: Equatable, Sendable {
    public let userCode: String
    public let deviceCode: String
    public let verificationURL: String
    public let message: String
    public let expiresInSeconds: Int
    public let pollIntervalSeconds: Int

    public init(
        userCode: String,
        deviceCode: String,
        verificationURL: String,
        message: String,
        expiresInSeconds: Int,
        pollIntervalSeconds: Int = 5
    ) {
        self.userCode = userCode
        self.deviceCode = deviceCode
        self.verificationURL = verificationURL
        self.message = message
        self.expiresInSeconds = expiresInSeconds
        self.pollIntervalSeconds = pollIntervalSeconds
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
