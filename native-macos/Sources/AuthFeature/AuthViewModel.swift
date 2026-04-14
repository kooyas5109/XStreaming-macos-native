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
