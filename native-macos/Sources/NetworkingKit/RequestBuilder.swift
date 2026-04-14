import Foundation

public enum RequestBuilderError: Error, Equatable {
    case invalidURL(String)
}

public enum RequestBuilder {
    public static func make(
        baseURL: URL,
        endpoint: some Endpoint,
        token: String? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        ) else {
            throw RequestBuilderError.invalidURL(endpoint.path)
        }

        if endpoint.queryItems.isEmpty == false {
            components.queryItems = endpoint.queryItems
        }

        guard let url = components.url else {
            throw RequestBuilderError.invalidURL(endpoint.path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token, token.isEmpty == false {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        endpoint.headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    public static func make(
        baseURL: URL,
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        token: String? = nil
    ) throws -> URLRequest {
        try make(
            baseURL: baseURL,
            endpoint: BasicEndpoint(
                path: path,
                method: method,
                queryItems: queryItems,
                headers: headers,
                body: body
            ),
            token: token
        )
    }
}
