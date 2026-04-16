import Foundation
import NetworkingKit
import PersistenceKit
import SharedDomain
import Testing
@testable import StreamingFeature

@Test
func liveStreamingRepositoryCreatesAndRefreshesHomeSession() async throws {
    let session = MockURLSession(responses: [
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "sessionPath": "/v5/sessions/home/session-123",
              "state": "Provisioning"
            }
            """
        ),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "state": "ReadyToConnect"
            }
            """
        )
    ])
    let repository = LiveStreamingRepository(
        httpClient: HTTPClient(session: session),
        tokenStore: InMemoryTokenStore(
            initialValue: StoredTokens(
                xHomeStreamingToken: "xhome-token",
                xHomeBaseURI: "https://home.example.com"
            )
        )
    )

    let created = try await repository.createSession(kind: .home, targetID: "console-1")
    let refreshed = try await repository.refreshSession(sessionID: created.id)

    #expect(created.id == "session-123")
    #expect(created.state == .pending)
    #expect(refreshed.state == .readyToConnect)
    #expect(await session.requestURLs == [
        "https://home.example.com/v5/sessions/home/play",
        "https://home.example.com/v5/sessions/home/session-123/state"
    ])
    #expect(await session.authorizationHeaders == [
        "Bearer xhome-token",
        "Bearer xhome-token"
    ])
    let body = try #require(await session.requestBodies.first)
    #expect(body.contains("\"serverId\":\"console-1\""))
    #expect(body.contains("\"titleId\":\"\""))
}

@Test
func liveStreamingRepositoryStopsHomeSession() async throws {
    let session = MockURLSession(responses: [
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "sessionPath": "/v5/sessions/home/session-123",
              "state": "Provisioning"
            }
            """
        ),
        MockURLSession.Response(statusCode: 204, body: "")
    ])
    let repository = LiveStreamingRepository(
        httpClient: HTTPClient(session: session),
        tokenStore: InMemoryTokenStore(
            initialValue: StoredTokens(
                xHomeStreamingToken: "xhome-token",
                xHomeBaseURI: "https://home.example.com"
            )
        )
    )

    let created = try await repository.createSession(kind: .home, targetID: "console-1")
    try await repository.stopSession(sessionID: created.id)

    #expect(await session.requestMethods == ["POST", "DELETE"])
    #expect(await session.requestURLs.last == "https://home.example.com/v5/sessions/home/session-123")
}

private actor RequestCapture {
    private(set) var requestURLs: [String] = []
    private(set) var requestMethods: [String] = []
    private(set) var authorizationHeaders: [String] = []
    private(set) var requestBodies: [String] = []

    func record(_ request: URLRequest) {
        requestURLs.append(request.url?.absoluteString ?? "")
        requestMethods.append(request.httpMethod ?? "")
        authorizationHeaders.append(request.value(forHTTPHeaderField: "Authorization") ?? "")
        if let body = request.httpBody {
            requestBodies.append(String(data: body, encoding: .utf8) ?? "")
        }
    }
}

private final class MockURLSession: URLSessionProviding, @unchecked Sendable {
    struct Response: Sendable {
        let statusCode: Int
        let body: String
    }

    private let responses: [Response]
    private let capture = RequestCapture()
    private var index = 0

    init(responses: [Response]) {
        self.responses = responses
    }

    var requestURLs: [String] {
        get async { await capture.requestURLs }
    }

    var requestMethods: [String] {
        get async { await capture.requestMethods }
    }

    var authorizationHeaders: [String] {
        get async { await capture.authorizationHeaders }
    }

    var requestBodies: [String] {
        get async { await capture.requestBodies }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        await capture.record(request)
        let response = responses[index]
        index += 1
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
