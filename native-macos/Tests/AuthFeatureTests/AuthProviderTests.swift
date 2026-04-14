import Foundation
import NetworkingKit
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
              "gsToken": "xhome-stream-token"
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
              "gsToken": "xcloud-stream-token"
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
    #expect(result.tokens.refreshToken == "refresh-token")
    #expect(result.tokens.xHomeStreamingToken == "xhome-stream-token")
    #expect(result.tokens.xCloudStreamingToken == "xcloud-stream-token")
    #expect(await session.consumedResponses == 9)
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
