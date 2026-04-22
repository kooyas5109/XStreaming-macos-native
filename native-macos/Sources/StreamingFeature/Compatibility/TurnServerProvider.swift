import Foundation
import NetworkingKit
import SharedDomain

public protocol TurnServerConfigurationProvider: Sendable {
    func loadDefaultTurnServer() async -> TurnServerConfiguration?
}

public struct SupportTurnServerConfigurationProvider: TurnServerConfigurationProvider {
    private let httpClient: HTTPClient
    private let endpoint: URL

    public init(
        httpClient: HTTPClient = HTTPClient(),
        endpoint: URL = URL(string: "https://xstreaming-support.pages.dev/server.json")!
    ) {
        self.httpClient = httpClient
        self.endpoint = endpoint
    }

    public func loadDefaultTurnServer() async -> TurnServerConfiguration? {
        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.timeoutInterval = 10

            let response = try await httpClient.send(request)
            guard response.response.statusCode == 200 else { return nil }

            let payload = try JSONDecoder().decode(SupportTurnServerResponse.self, from: response.data)
            let turnServer = payload.asDomain()
            return turnServer.isComplete ? turnServer : nil
        } catch {
            return nil
        }
    }
}

private struct SupportTurnServerResponse: Decodable {
    let url: String?
    let username: String?
    let credential: String?

    func asDomain() -> TurnServerConfiguration {
        TurnServerConfiguration(
            url: url ?? "",
            username: username ?? "",
            credential: credential ?? ""
        )
    }
}

extension TurnServerConfiguration {
    var isComplete: Bool {
        url.isEmpty == false &&
        username.isEmpty == false &&
        credential.isEmpty == false
    }
}
