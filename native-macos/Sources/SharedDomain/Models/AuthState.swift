import Foundation

public struct AuthState: Codable, Equatable, Sendable {
    public let isSignedIn: Bool
    public let isAuthenticating: Bool
    public let userProfile: UserProfile?
    public let statusMessage: String?

    public init(
        isSignedIn: Bool,
        isAuthenticating: Bool = false,
        userProfile: UserProfile? = nil,
        statusMessage: String? = nil
    ) {
        self.isSignedIn = isSignedIn
        self.isAuthenticating = isAuthenticating
        self.userProfile = userProfile
        self.statusMessage = statusMessage
    }
}

public extension AuthState {
    static let signedOut = AuthState(isSignedIn: false)
}
