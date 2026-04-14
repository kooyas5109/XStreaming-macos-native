import Foundation
import NetworkingKit
import PersistenceKit
import SharedDomain
import Testing
@testable import ConsoleFeature

@Test
func consoleServiceLoadsCachedThenRemoteConsoles() async throws {
    let cacheStore = InMemoryCacheStore()
    let cached = [
        ConsoleDevice(
            id: "cached-console",
            name: "Cached Xbox",
            consoleType: .xboxOne,
            powerState: .on
        )
    ]
    try cacheStore.save(CacheEnvelope(value: cached), forKey: "consoles")

    let service = ConsoleService(
        repository: PreviewConsoleRepository(consoles: ConsoleFixtures.sampleConsoles),
        cacheStore: cacheStore
    )

    let result = try await service.loadConsoles()
    #expect(result.cached.count == 1)
    #expect(result.remote.count == 2)
    #expect(result.remote.first?.name == "Living Room Xbox")
}

@Test
func liveConsoleRepositoryFetchesLegacyDeviceList() async throws {
    let session = MockURLSession(responses: [
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "status": {
                "errorCode": "OK",
                "errorMessage": null
              },
              "result": [
                {
                  "id": "FD00000000000000",
                  "name": "XBOXONE",
                  "consoleType": "XboxOneS",
                  "powerState": "ConnectedStandby",
                  "remoteManagementEnabled": true,
                  "consoleStreamingEnabled": true,
                  "wirelessWarning": false,
                  "outOfHomeWarning": false,
                  "storageDevices": [
                    {
                      "storageDeviceId": "storage-1",
                      "storageDeviceName": "Internal",
                      "isDefault": true,
                      "freeSpaceBytes": 100,
                      "totalSpaceBytes": 200,
                      "isGen9Compatible": true
                    }
                  ]
                }
              ]
            }
            """
        )
    ])
    let repository = LiveConsoleRepository(
        httpClient: HTTPClient(session: session),
        tokenStore: InMemoryTokenStore(
            initialValue: StoredTokens(
                webToken: "web-token",
                userHash: "12345"
            )
        )
    )

    let consoles = try await repository.fetchConsoles()

    #expect(consoles.count == 1)
    #expect(consoles.first?.id == "FD00000000000000")
    #expect(consoles.first?.consoleType == .xboxOneS)
    #expect(consoles.first?.powerState == .connectedStandby)
    #expect(consoles.first?.storageDevices.first?.name == "Internal")
    #expect(await session.lastRequestURL == "https://xccs.xboxlive.com/lists/devices?queryCurrentDevice=false&includeStorageDevices=true")
    #expect(await session.lastAuthorization == "XBL3.0 x=12345;web-token")
}

@Test
func liveConsoleRepositorySendsLegacyCommandPayload() async throws {
    let session = MockURLSession(responses: [
        MockURLSession.Response(
            statusCode: 200,
            body: """
            {
              "status": {
                "errorCode": "OK",
                "errorMessage": null
              }
            }
            """
        )
    ])
    let repository = LiveConsoleRepository(
        httpClient: HTTPClient(session: session),
        tokenStore: InMemoryTokenStore(
            initialValue: StoredTokens(
                webToken: "web-token",
                userHash: "12345"
            )
        )
    )

    try await repository.sendText(consoleID: "FD00000000000000", text: "hello")

    let body = await session.lastBody ?? ""
    #expect(await session.lastRequestURL == "https://xccs.xboxlive.com/commands")
    #expect(body.contains("\"type\":\"Shell\""))
    #expect(body.contains("\"command\":\"InjectString\""))
    #expect(body.contains("\"linkedXboxId\":\"FD00000000000000\""))
    #expect(body.contains("\"replacementString\":\"hello\""))
}

private actor RequestCapture {
    private(set) var lastRequestURL: String?
    private(set) var lastAuthorization: String?
    private(set) var lastBody: String?

    func record(_ request: URLRequest) {
        lastRequestURL = request.url?.absoluteString
        lastAuthorization = request.value(forHTTPHeaderField: "Authorization")
        if let body = request.httpBody {
            lastBody = String(data: body, encoding: .utf8)
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

    var lastRequestURL: String? {
        get async { await capture.lastRequestURL }
    }

    var lastAuthorization: String? {
        get async { await capture.lastAuthorization }
    }

    var lastBody: String? {
        get async { await capture.lastBody }
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
