import Foundation

public struct HTTPResponse: Equatable, Sendable {
    public let data: Data
    public let response: HTTPURLResponse

    public init(data: Data, response: HTTPURLResponse) {
        self.data = data
        self.response = response
    }
}

public protocol URLSessionProviding: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProviding {}

public enum HTTPClientError: Error, Equatable {
    case invalidResponse
}

public final class HTTPClient: @unchecked Sendable {
    private let session: URLSessionProviding
    private let retryPolicy: RetryPolicy
    private let decoder: JSONDecoder

    public init(
        session: URLSessionProviding = URLSession.shared,
        retryPolicy: RetryPolicy = RetryPolicy(),
        decoder: JSONDecoder = JSONDecoderFactory.make()
    ) {
        self.session = session
        self.retryPolicy = retryPolicy
        self.decoder = decoder
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        var attempt = 1

        while true {
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HTTPClientError.invalidResponse
                }

                if retryPolicy.shouldRetry(statusCode: httpResponse.statusCode, attempt: attempt) {
                    attempt += 1
                    continue
                }

                return HTTPResponse(data: data, response: httpResponse)
            } catch {
                if retryPolicy.shouldRetry(error: error, attempt: attempt) {
                    attempt += 1
                    continue
                }

                throw error
            }
        }
    }

    public func decode<Response: Decodable>(_ type: Response.Type, from response: HTTPResponse) throws -> Response {
        try decoder.decode(Response.self, from: response.data)
    }
}
