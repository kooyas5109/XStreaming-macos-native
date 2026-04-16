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
    #expect(state.userProfile?.gamertag == "Native Preview User")
}

@Test
func authServicePersistsRefreshedTokensDuringRestore() async throws {
    let tokenStore = InMemoryTokenStore(
        initialValue: StoredTokens(authToken: "old-auth-token")
    )
    let refreshedTokens = StoredTokens(
        authToken: "new-auth-token",
        refreshToken: "new-refresh-token",
        webToken: "new-web-token",
        userHash: "new-user-hash",
        xHomeStreamingToken: "new-xhome-token"
    )
    let service = AuthService(
        repository: RestoringAuthRepository(
            result: AuthSignInResult(
                authState: AuthState(isSignedIn: true, statusMessage: "Refreshed"),
                tokens: refreshedTokens
            )
        ),
        tokenStore: tokenStore
    )

    let state = try await service.restoreSession()
    let persisted = try tokenStore.load()

    #expect(state.isSignedIn == true)
    #expect(persisted == refreshedTokens)
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
    #expect(persisted?.refreshToken == "native-refresh-token")
    #expect(persisted?.webToken == "native-web-token")
    #expect(persisted?.userHash == "preview-user-hash")
    #expect(persisted?.xHomeStreamingToken == "native-xhome-token")
    #expect(persisted?.xCloudStreamingToken == "native-xcloud-token")
}

private struct RestoringAuthRepository: AuthRepository {
    let result: AuthSignInResult

    func restoreSession(from tokens: StoredTokens?) async throws -> AuthSignInResult {
        result
    }

    func beginInteractiveSignIn() async throws -> DeviceCodeChallenge {
        DeviceCodeChallenge(
            userCode: "ABCD-EFGH",
            deviceCode: "device-code",
            verificationURL: "https://www.microsoft.com/link",
            message: "Sign in",
            expiresInSeconds: 900
        )
    }

    func completeInteractiveSignIn(using challenge: DeviceCodeChallenge) async throws -> AuthSignInResult {
        result
    }

    func signOut() async throws {}
}
