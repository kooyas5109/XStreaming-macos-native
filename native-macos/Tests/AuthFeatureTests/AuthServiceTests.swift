import PersistenceKit
import SharedDomain
import Testing
@testable import AuthFeature

@Test
func authServiceReportsSignedOutWithoutTokens() async throws {
    let service = AuthService.previewSignedOut()
    let state = try await service.restoreSession()
    #expect(state.isSignedIn == false)
}

@Test
func authServiceRestoresSignedInStateWithStoredTokens() async throws {
    let tokenStore = InMemoryTokenStore(
        initialValue: StoredTokens(authToken: "auth-token")
    )
    let service = AuthService(
        repository: DefaultAuthRepository(),
        tokenStore: tokenStore
    )

    let state = try await service.restoreSession()
    #expect(state.isSignedIn == true)
    #expect(state.userProfile?.gamertag == "Signed In User")
}
