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

@Test
func liveStreamingRepositoryConnectsReadySessionWithTransferToken() async throws {
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
              "lpt": "live-passport-transfer-token",
              "refresh_token": "new-refresh-token",
              "user_id": "user-1"
            }
            """
        ),
        MockURLSession.Response(statusCode: 200, body: "{}"),
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "state": "Provisioned"
            }
            """
        )
    ])
    let repository = LiveStreamingRepository(
        httpClient: HTTPClient(session: session),
        tokenStore: InMemoryTokenStore(
            initialValue: StoredTokens(
                refreshToken: "refresh-token+with&symbols=",
                xHomeStreamingToken: "xhome-token",
                xHomeBaseURI: "https://home.example.com"
            )
        )
    )

    let created = try await repository.createSession(kind: .home, targetID: "console-1")
    let connected = try await repository.connectSession(sessionID: created.id)

    #expect(connected.state == .started)
    #expect(await session.requestMethods == ["POST", "POST", "POST", "GET"])
    #expect(await session.requestURLs == [
        "https://home.example.com/v5/sessions/home/play",
        "https://login.live.com/oauth20_token.srf",
        "https://home.example.com/v5/sessions/home/session-123/connect",
        "https://home.example.com/v5/sessions/home/session-123/state"
    ])
    #expect(await session.authorizationHeaders == [
        "Bearer xhome-token",
        "",
        "Bearer xhome-token",
        "Bearer xhome-token"
    ])
    let bodies = await session.requestBodies
    #expect(bodies[1].contains("grant_type=refresh_token"))
    #expect(bodies[1].contains("refresh_token=refresh-token%2Bwith%26symbols%3D"))
    #expect(bodies[1].contains("PURPOSE_XBOX_CLOUD_CONSOLE_TRANSFER_TOKEN"))
    #expect(bodies[2].contains("\"userToken\":\"live-passport-transfer-token\""))
}

@Test
func liveStreamingRepositoryExchangesSdpOfferForRemoteAnswer() async throws {
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
        MockURLSession.Response(statusCode: 200, body: "{}"),
        MockURLSession.Response(
            statusCode: 200,
            body: #"""
            {
              "exchangeResponse": "{\"messageType\":\"answer\",\"sdp\":\"v=0\\r\\nremote-answer\"}"
            }
            """#
        )
    ])
    let repository = LiveStreamingRepository(
        httpClient: HTTPClient(session: session),
        tokenStore: InMemoryTokenStore(
            initialValue: StoredTokens(
                xHomeStreamingToken: "xhome-token",
                xHomeBaseURI: "https://home.example.com"
            )
        ),
        exchangePollIntervalNanoseconds: 1_000
    )

    let created = try await repository.createSession(kind: .home, targetID: "console-1")
    let answer = try await repository.exchangeSDP(sessionID: created.id, offerSDP: "v=0\r\nlocal-offer")

    #expect(answer.messageType == "answer")
    #expect(answer.sdp == "v=0\r\nremote-answer")
    #expect(await session.requestMethods == ["POST", "POST", "GET"])
    #expect(await session.requestURLs == [
        "https://home.example.com/v5/sessions/home/play",
        "https://home.example.com/v5/sessions/home/session-123/sdp",
        "https://home.example.com/v5/sessions/home/session-123/sdp"
    ])
    let bodies = await session.requestBodies
    #expect(bodies[1].contains("\"messageType\":\"offer\""))
    #expect(bodies[1].contains("\"sdp\":\"v=0\\r\\nlocal-offer\""))
    #expect(bodies[1].contains("\"control\""))
    #expect(bodies[1].contains("\"minVersion\":1"))
    #expect(bodies[1].contains("\"maxVersion\":3"))
    #expect(bodies[1].contains("\"input\""))
    #expect(bodies[1].contains("\"maxVersion\":8"))
}

@Test
func liveStreamingRepositoryExchangesIceCandidateForRemoteCandidates() async throws {
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
        MockURLSession.Response(statusCode: 200, body: "{}"),
        MockURLSession.Response(
            statusCode: 200,
            body: #"""
            {
              "exchangeResponse": "[{\"messageType\":\"iceCandidate\",\"candidate\":\"a=candidate:2 1 UDP 1 10.0.0.2 9002 typ host\",\"sdpMid\":\"0\",\"sdpMLineIndex\":0}]"
            }
            """#
        )
    ])
    let repository = LiveStreamingRepository(
        httpClient: HTTPClient(session: session),
        tokenStore: InMemoryTokenStore(
            initialValue: StoredTokens(
                xHomeStreamingToken: "xhome-token",
                xHomeBaseURI: "https://home.example.com"
            )
        ),
        exchangePollIntervalNanoseconds: 1_000
    )

    let created = try await repository.createSession(kind: .home, targetID: "console-1")
    let candidates = try await repository.exchangeICE(
        sessionID: created.id,
        candidate: "a=candidate:1 1 UDP 1 10.0.0.1 9002 typ host"
    )

    #expect(candidates == [
        StreamingICECandidate(
            messageType: "iceCandidate",
            candidate: "a=candidate:2 1 UDP 1 10.0.0.2 9002 typ host",
            sdpMid: "0",
            sdpMLineIndex: "0"
        )
    ])
    #expect(await session.requestMethods == ["POST", "POST", "GET"])
    #expect(await session.requestURLs == [
        "https://home.example.com/v5/sessions/home/play",
        "https://home.example.com/v5/sessions/home/session-123/ice",
        "https://home.example.com/v5/sessions/home/session-123/ice"
    ])
    let bodies = await session.requestBodies
    #expect(bodies[1].contains("\"messageType\":\"iceCandidate\""))
    #expect(bodies[1].contains("\"candidate\":\"a=candidate:1 1 UDP 1 10.0.0.1 9002 typ host\""))
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
