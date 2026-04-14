import Foundation
import SharedDomain

@MainActor
public final class AuthViewModel: ObservableObject {
    @Published public private(set) var state: AuthViewState

    private let service: AuthService

    public init(
        service: AuthService,
        initialState: AuthViewState = AuthViewState()
    ) {
        self.service = service
        self.state = initialState
    }

    public func restoreSession() async {
        state.authState = AuthState(
            isSignedIn: state.authState.isSignedIn,
            isAuthenticating: true,
            userProfile: state.authState.userProfile,
            statusMessage: "Restoring session..."
        )

        do {
            let restoredState = try await service.restoreSession()
            state = AuthViewState(authState: restoredState)
        } catch {
            state = AuthViewState(
                authState: .signedOut,
                errorMessage: error.localizedDescription
            )
        }
    }

    public func beginInteractiveSignIn() async {
        state.errorMessage = nil
        state.authState = AuthState(
            isSignedIn: false,
            isAuthenticating: true,
            userProfile: state.authState.userProfile,
            statusMessage: "Requesting device code..."
        )

        do {
            let challenge = try await service.beginInteractiveSignIn()
            state.authState = AuthState(
                isSignedIn: false,
                isAuthenticating: false,
                userProfile: nil,
                statusMessage: challenge.message
            )
            state.deviceCodeChallenge = challenge
        } catch {
            state.authState = .signedOut
            state.errorMessage = error.localizedDescription
        }
    }

    public func completeInteractiveSignIn() async {
        guard let challenge = state.deviceCodeChallenge else { return }
        state.errorMessage = nil
        state.authState = AuthState(
            isSignedIn: false,
            isAuthenticating: true,
            userProfile: nil,
            statusMessage: "Waiting for device code confirmation..."
        )

        do {
            let signedInState = try await service.completeInteractiveSignIn(using: challenge)
            state = AuthViewState(authState: signedInState)
        } catch {
            state.authState = .signedOut
            state.errorMessage = error.localizedDescription
        }
    }

    public func signOut() async {
        do {
            let signedOutState = try await service.signOut()
            state = AuthViewState(authState: signedOutState)
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    public static func previewSignedOut() -> AuthViewModel {
        AuthViewModel(service: .previewSignedOut())
    }
}
