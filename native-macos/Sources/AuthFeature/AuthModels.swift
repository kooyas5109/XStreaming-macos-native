import Foundation
import SharedDomain

public struct AuthViewState: Equatable, Sendable {
    public var authState: AuthState
    public var errorMessage: String?

    public init(
        authState: AuthState = .signedOut,
        errorMessage: String? = nil
    ) {
        self.authState = authState
        self.errorMessage = errorMessage
    }
}
