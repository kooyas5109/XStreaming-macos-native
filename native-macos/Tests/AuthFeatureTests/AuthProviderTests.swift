import Foundation
import NetworkingKit
import PersistenceKit
import Testing
@testable import AuthFeature

@Test
func authProviderModeDefaultsToPreview() {
    #expect(AuthProviderMode(environmentValue: nil) == .preview)
    #expect(AuthProviderMode(environmentValue: "preview") == .preview)
}

@Test
func authProviderModeParsesLiveValue() {
    #expect(AuthProviderMode(environmentValue: "live") == .live)
    #expect(AuthProviderMode(environmentValue: "LIVE") == .live)
}

@Test
func liveProviderPollsUntilDeviceCodeCompletes() async throws {
    let session = MockURLSession(responses: [
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "user_code": "ABCD-EFGH",
              "device_code": "device-code-123",
              "verification_uri": "https://microsoft.com/devicelogin",
              "expires_in": 900,
              "interval": 1,
              "message": "Enter the code to continue."
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 400,
            body: """
            {
              "error": "authorization_pending"
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "access_token": "access-token",
              "refresh_token": "refresh-token",
              "expires_in": 3600,
              "token_type": "Bearer"
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "Token": "user-token",
              "DisplayClaims": {
                "xui": [
                  { "uhs": "12345" }
                ]
              }
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "Token": "web-token",
              "DisplayClaims": {
                "xui": [
                  { "uhs": "12345" }
                ]
              }
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "Token": "gssv-token",
              "DisplayClaims": {
                "xui": [
                  { "uhs": "12345" }
                ]
              }
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "profileUsers": [
                {
                  "settings": [
                    { "id": "Gamertag", "value": "Kooyas" },
                    { "id": "GameDisplayPicRaw", "value": "https://example.com/gamerpic.png" },
                    { "id": "Gamerscore", "value": "67890" }
                  ]
                }
              ]
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "gsToken": "xhome-stream-token",
              "offeringSettings": {
                "regions": [
                  {
                    "name": "home-default",
                    "baseUri": "https://home.example.com",
                    "isDefault": true
                  }
                ]
              }
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 500,
            body: """
            {
              "error": "unsupported_region"
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "gsToken": "xcloud-stream-token",
              "offeringSettings": {
                "regions": [
                  {
                    "name": "cloud-default",
                    "baseUri": "https://cloud.example.com",
                    "isDefault": true
                  }
                ]
              }
            }
            """
        )
    ])

    let provider = LiveXboxAuthProvider(
        httpClient: HTTPClient(session: session)
    )

    let challenge = try await provider.requestDeviceCode()
    let result = try await provider.completeDeviceCode(challenge: challenge)

    #expect(challenge.deviceCode == "device-code-123")
    #expect(result.authState.userProfile?.gamertag == "Kooyas")
    #expect(result.tokens.refreshToken == "refresh-token")
    #expect(result.tokens.userHash == "12345")
    #expect(result.tokens.xHomeStreamingToken == "xhome-stream-token")
    #expect(result.tokens.xHomeBaseURI == "https://home.example.com")
    #expect(result.tokens.xCloudStreamingToken == "xcloud-stream-token")
    #expect(result.tokens.xCloudBaseURI == "https://cloud.example.com")
    #expect(await session.consumedResponses == 10)
}

@Test
func liveProviderRestoresSessionWithStoredProfileTokens() async throws {
    let session = MockURLSession(responses: [
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "profileUsers": [
                {
                  "settings": [
                    { "id": "Gamertag", "value": "Restored User" },
                    { "id": "Gamerscore", "value": "321" }
                  ]
                }
              ]
            }
            """
        )
    ])

    let provider = LiveXboxAuthProvider(
        httpClient: HTTPClient(session: session)
    )
    let result = try await provider.restoreSession(
        from: StoredTokens(
            authToken: "access-token",
            webToken: "web-token",
            userHash: "12345"
        )
    )
    let state = result.authState

    #expect(state.isSignedIn == true)
    #expect(state.userProfile?.gamertag == "Restored User")
    #expect(result.tokens.webToken == "web-token")
    #expect(await session.consumedResponses == 1)
}

@Test
func liveProviderRestoresSessionWhenStoredProfileCannotDecode() async throws {
    let session = MockURLSession(responses: [
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "error": "profile_unavailable"
            }
            """
        )
    ])

    let provider = LiveXboxAuthProvider(
        httpClient: HTTPClient(session: session)
    )
    let result = try await provider.restoreSession(
        from: StoredTokens(
            authToken: "access-token",
            webToken: "web-token",
            userHash: "12345"
        )
    )
    let state = result.authState

    #expect(state.isSignedIn == true)
    #expect(state.userProfile == nil)
    #expect(state.statusMessage == "Restored live session from stored tokens. Profile refresh is unavailable.")
    #expect(await session.consumedResponses == 1)
}

@Test
func liveProviderRefreshesStoredSessionWhenProfileTokenIsUnavailable() async throws {
    let session = MockURLSession(responses: [
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "access_token": "new-access-token",
              "refresh_token": "new-refresh-token",
              "expires_in": 3600,
              "token_type": "Bearer"
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "Token": "user-token",
              "DisplayClaims": {
                "xui": [
                  { "uhs": "12345" }
                ]
              }
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "Token": "new-web-token",
              "DisplayClaims": {
                "xui": [
                  { "uhs": "12345" }
                ]
              }
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "Token": "new-gssv-token",
              "DisplayClaims": {
                "xui": [
                  { "uhs": "12345" }
                ]
              }
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "profileUsers": [
                {
                  "settings": [
                    { "id": "Gamertag", "value": "Refreshed User" },
                    { "id": "Gamerscore", "value": "999" }
                  ]
                }
              ]
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "gsToken": "new-xhome-token",
              "offeringSettings": {
                "regions": [
                  {
                    "baseUri": "https://home.example.com",
                    "isDefault": true
                  }
                ]
              }
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "gsToken": "new-xcloud-token",
              "offeringSettings": {
                "regions": [
                  {
                    "baseUri": "https://cloud.example.com",
                    "isDefault": true
                  }
                ]
              }
            }
            """
        )
    ])

    let provider = LiveXboxAuthProvider(
        httpClient: HTTPClient(session: session)
    )
    let result = try await provider.restoreSession(
        from: StoredTokens(
            authToken: "old-access-token",
            refreshToken: "stored-refresh-token"
        )
    )

    #expect(result.authState.isSignedIn == true)
    #expect(result.authState.userProfile?.gamertag == "Refreshed User")
    #expect(result.authState.statusMessage == "Refreshed live session from stored refresh token.")
    #expect(result.tokens.authToken == "new-access-token")
    #expect(result.tokens.refreshToken == "new-refresh-token")
    #expect(result.tokens.webToken == "new-web-token")
    #expect(result.tokens.userHash == "12345")
    #expect(result.tokens.xHomeStreamingToken == "new-xhome-token")
    #expect(result.tokens.xHomeBaseURI == "https://home.example.com")
    #expect(result.tokens.xCloudStreamingToken == "new-xcloud-token")
    #expect(result.tokens.xCloudBaseURI == "https://cloud.example.com")
    #expect(await session.consumedResponses == 7)
}

private actor ResponseCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private final class MockURLSession: URLSessionProviding, @unchecked Sendable {
    struct Response: Sendable {
        let statusCode: Int
        let body: String
    }

    private let responses: [Response]
    private let counter = ResponseCounter()
    private var index = 0

    init(responses: [Response]) {
        self.responses = responses
    }

    var consumedResponses: Int {
        get async {
            await counter.value
        }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = responses[index]
        index += 1
        await counter.increment()
        let url = try #require(request.url)
        let httpResponse = try #require(
            HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: nil,
                headerFields: nil
            )
        )
        return (Data(response.body.utf8), httpResponse)
    }
}
