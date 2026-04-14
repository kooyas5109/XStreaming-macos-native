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

@Test
func authServiceCompletesDeviceCodeFlowAndPersistsTokens() async throws {
    let tokenStore = InMemoryTokenStore()
    let service = AuthService(
        repository: DefaultAuthRepository(),
        tokenStore: tokenStore
    )

    let challenge = try await service.beginInteractiveSignIn()
    let state = try await service.completeInteractiveSignIn(using: challenge)
    let persisted = try tokenStore.load()

    #expect(challenge.userCode.isEmpty == false)
    #expect(state.isSignedIn == true)
    #expect(persisted?.authToken?.isEmpty == false)
    #expect(persisted?.webToken == "native-web-token")
}
