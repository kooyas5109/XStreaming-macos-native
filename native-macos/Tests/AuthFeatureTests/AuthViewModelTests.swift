import PersistenceKit
import SharedDomain
import Testing
@testable import AuthFeature

@MainActor
@Test
func authViewModelStartsSignedOutInPreview() {
    let viewModel = AuthViewModel.previewSignedOut()
    #expect(viewModel.state.authState.isSignedIn == false)
}

@MainActor
@Test
func authViewModelRestoresStateFromService() async {
    let tokenStore = InMemoryTokenStore(
        initialValue: StoredTokens(authToken: "auth-token")
    )
    let service = AuthService(
        repository: DefaultAuthRepository(),
        tokenStore: tokenStore
    )
    let viewModel = AuthViewModel(service: service)

    await viewModel.restoreSession()

    #expect(viewModel.state.authState.isSignedIn == true)
    #expect(viewModel.state.errorMessage == nil)
}
