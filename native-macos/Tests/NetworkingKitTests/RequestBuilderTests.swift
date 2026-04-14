import Foundation
import Testing
@testable import NetworkingKit

@Test
func requestBuilderInjectsBearerToken() throws {
    let request = try RequestBuilder.make(
        baseURL: URL(string: "https://example.com")!,
        path: "/v2/titles",
        token: "abc"
    )

    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
    #expect(request.httpMethod == "GET")
    #expect(request.url?.absoluteString == "https://example.com/v2/titles")
}

@Test
func requestBuilderAddsQueryItemsAndHeaders() throws {
    let request = try RequestBuilder.make(
        baseURL: URL(string: "https://example.com")!,
        path: "/v2/titles",
        method: .post,
        queryItems: [URLQueryItem(name: "mr", value: "25")],
        headers: ["x-test-header": "value"],
        body: Data("{}".utf8)
    )

    #expect(request.url?.absoluteString == "https://example.com/v2/titles?mr=25")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "x-test-header") == "value")
    #expect(request.httpBody == Data("{}".utf8))
}
