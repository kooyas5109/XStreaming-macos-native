import Foundation
import NetworkingKit
import Testing

@Test
func titlesEndpointMatchesLegacyCloudTitlesPath() throws {
    let request = try RequestBuilder.make(
        baseURL: URL(string: "https://example.com")!,
        path: "/v2/titles",
        token: "abc"
    )

    #expect(request.httpMethod == "GET")
    #expect(request.url?.absoluteString == "https://example.com/v2/titles")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
}

@Test
func recentTitlesEndpointMatchesLegacyMRUQuery() throws {
    let request = try RequestBuilder.make(
        baseURL: URL(string: "https://example.com")!,
        path: "/v2/titles/mru",
        queryItems: [URLQueryItem(name: "mr", value: "25")],
        token: "abc"
    )

    #expect(request.url?.absoluteString == "https://example.com/v2/titles/mru?mr=25")
}

@Test
func streamStartEndpointMatchesLegacyPlayPathAndHeaders() throws {
    let body = try JSONSerialization.data(withJSONObject: ["titleId": "title-1"])
    let request = try RequestBuilder.make(
        baseURL: URL(string: "https://example.com")!,
        path: "/v5/sessions/cloud/play",
        method: .post,
        headers: ["X-MS-Device-Info": "{\"device\":\"preview\"}"],
        body: body,
        token: "abc"
    )

    #expect(request.httpMethod == "POST")
    #expect(request.url?.absoluteString == "https://example.com/v5/sessions/cloud/play")
    #expect(request.value(forHTTPHeaderField: "X-MS-Device-Info") == "{\"device\":\"preview\"}")
    #expect(request.httpBody == body)
}

@Test
func sdpEndpointMatchesLegacyExchangePath() throws {
    let body = try JSONSerialization.data(
        withJSONObject: ["messageType": "offer", "sdp": "v=0"]
    )
    let request = try RequestBuilder.make(
        baseURL: URL(string: "https://example.com")!,
        path: "/v5/sessions/cloud/session-1/sdp",
        method: .post,
        body: body,
        token: "abc"
    )

    #expect(request.httpMethod == "POST")
    #expect(request.url?.absoluteString == "https://example.com/v5/sessions/cloud/session-1/sdp")
}

@Test
func iceEndpointMatchesLegacyCandidateExchangePath() throws {
    let body = try JSONSerialization.data(
        withJSONObject: ["messageType": "iceCandidate", "candidate": "a=candidate:1 1 UDP 1 127.0.0.1 1234 typ host"]
    )
    let request = try RequestBuilder.make(
        baseURL: URL(string: "https://example.com")!,
        path: "/v5/sessions/cloud/session-1/ice",
        method: .post,
        body: body,
        token: "abc"
    )

    #expect(request.httpMethod == "POST")
    #expect(request.url?.absoluteString == "https://example.com/v5/sessions/cloud/session-1/ice")
}
