import Foundation
import NetworkingKit
import PersistenceKit
import SharedDomain

public protocol ConsoleRepository: Sendable {
    func fetchConsoles() async throws -> [ConsoleDevice]
    func powerOn(consoleID: String) async throws
    func powerOff(consoleID: String) async throws
    func sendText(consoleID: String, text: String) async throws
}

public struct PreviewConsoleRepository: ConsoleRepository {
    private let consoles: [ConsoleDevice]

    public init(consoles: [ConsoleDevice]) {
        self.consoles = consoles
    }

    public func fetchConsoles() async throws -> [ConsoleDevice] {
        consoles
    }

    public func powerOn(consoleID: String) async throws {}
    public func powerOff(consoleID: String) async throws {}
    public func sendText(consoleID: String, text: String) async throws {}
}

public enum ConsoleRepositoryError: Error, Equatable {
    case missingAuthContext
    case service(String)
}

public struct LiveConsoleRepository: ConsoleRepository {
    private let httpClient: HTTPClient
    private let tokenStore: TokenStoreProtocol
    private let baseURL: URL

    public init(
        httpClient: HTTPClient = HTTPClient(),
        tokenStore: TokenStoreProtocol,
        baseURL: URL = URL(string: "https://xccs.xboxlive.com")!
    ) {
        self.httpClient = httpClient
        self.tokenStore = tokenStore
        self.baseURL = baseURL
    }

    public func fetchConsoles() async throws -> [ConsoleDevice] {
        let auth = try loadAuthContext()
        let request = try RequestBuilder.make(
            baseURL: baseURL,
            endpoint: ConsoleEndpoints.devices(userToken: auth.webToken, userHash: auth.userHash)
        )
        let response = try await httpClient.send(request)
        let payload = try httpClient.decode(ConsoleListResponse.self, from: response)
        try payload.assertOK()
        return payload.result.map { $0.asConsoleDevice() }
    }

    public func powerOn(consoleID: String) async throws {
        try await sendCommand(consoleID: consoleID, type: "Power", command: "WakeUp")
    }

    public func powerOff(consoleID: String) async throws {
        try await sendCommand(consoleID: consoleID, type: "Power", command: "TurnOff")
    }

    public func sendText(consoleID: String, text: String) async throws {
        try await sendCommand(
            consoleID: consoleID,
            type: "Shell",
            command: "InjectString",
            parameters: [
                .dictionary(["replacementString": .string(text)])
            ]
        )
    }

    private func sendCommand(
        consoleID: String,
        type: String,
        command: String,
        parameters: [ConsoleCommandValue] = []
    ) async throws {
        let auth = try loadAuthContext()
        let endpoint = try ConsoleEndpoints.command(
            userToken: auth.webToken,
            userHash: auth.userHash,
            consoleID: consoleID,
            type: type,
            command: command,
            parameters: parameters
        )
        let request = try RequestBuilder.make(baseURL: baseURL, endpoint: endpoint)
        let response = try await httpClient.send(request)
        let payload = try httpClient.decode(ConsoleCommandResponse.self, from: response)
        try payload.assertOK()
    }

    private func loadAuthContext() throws -> ConsoleAuthContext {
        guard
            let tokens = try tokenStore.load(),
            let webToken = tokens.webToken, webToken.isEmpty == false,
            let userHash = tokens.userHash, userHash.isEmpty == false
        else {
            throw ConsoleRepositoryError.missingAuthContext
        }

        return ConsoleAuthContext(webToken: webToken, userHash: userHash)
    }
}

private struct ConsoleAuthContext {
    let webToken: String
    let userHash: String
}

enum ConsoleEndpoints {
    static func devices(userToken: String, userHash: String) -> BasicEndpoint {
        BasicEndpoint(
            path: "/lists/devices",
            method: .get,
            queryItems: [
                URLQueryItem(name: "queryCurrentDevice", value: "false"),
                URLQueryItem(name: "includeStorageDevices", value: "true")
            ],
            headers: baseHeaders(userToken: userToken, userHash: userHash)
        )
    }

    static func command(
        userToken: String,
        userHash: String,
        consoleID: String,
        type: String,
        command: String,
        parameters: [ConsoleCommandValue]
    ) throws -> BasicEndpoint {
        let body = try JSONEncoder().encode(
            ConsoleCommandRequest(
                destination: "Xbox",
                type: type,
                command: command,
                sessionID: UUID().uuidString.lowercased(),
                sourceID: "com.microsoft.smartglass",
                parameters: parameters,
                linkedXboxID: consoleID
            )
        )

        return BasicEndpoint(
            path: "/commands",
            method: .post,
            headers: baseHeaders(userToken: userToken, userHash: userHash),
            body: body
        )
    }

    private static func baseHeaders(userToken: String, userHash: String) -> [String: String] {
        [
            "Authorization": "XBL3.0 x=\(userHash);\(userToken)",
            "Accept-Language": "en-US",
            "x-xbl-contract-version": "4",
            "x-xbl-client-name": "XboxApp",
            "x-xbl-client-type": "UWA",
            "x-xbl-client-version": "39.39.22001.0",
            "skillplatform": "RemoteManagement",
            "Content-Type": "application/json"
        ]
    }
}

private struct ConsoleServiceStatus: Decodable {
    let errorCode: String
    let errorMessage: String?
}

private struct ConsoleListResponse: Decodable {
    struct RemoteConsole: Decodable {
        struct RemoteStorageDevice: Decodable {
            let storageDeviceID: String
            let storageDeviceName: String
            let isDefault: Bool
            let freeSpaceBytes: Int64
            let totalSpaceBytes: Int64
            let isGen9Compatible: Bool?

            enum CodingKeys: String, CodingKey {
                case storageDeviceID = "storageDeviceId"
                case storageDeviceName
                case isDefault
                case freeSpaceBytes
                case totalSpaceBytes
                case isGen9Compatible
            }

            func asStorageDevice() -> StorageDevice {
                StorageDevice(
                    id: storageDeviceID,
                    name: storageDeviceName,
                    isDefault: isDefault,
                    freeSpaceBytes: freeSpaceBytes,
                    totalSpaceBytes: totalSpaceBytes,
                    isGen9Compatible: isGen9Compatible
                )
            }
        }

        let id: String
        let name: String
        let locale: String?
        let region: String?
        let consoleType: String?
        let powerState: String?
        let remoteManagementEnabled: Bool?
        let consoleStreamingEnabled: Bool?
        let wirelessWarning: Bool?
        let outOfHomeWarning: Bool?
        let storageDevices: [RemoteStorageDevice]?

        func asConsoleDevice() -> ConsoleDevice {
            ConsoleDevice(
                id: id,
                name: name,
                locale: locale ?? "",
                region: region ?? "",
                consoleType: mappedConsoleType(consoleType),
                powerState: mappedPowerState(powerState),
                remoteManagementEnabled: remoteManagementEnabled ?? false,
                consoleStreamingEnabled: consoleStreamingEnabled ?? false,
                wirelessWarning: wirelessWarning ?? false,
                outOfHomeWarning: outOfHomeWarning ?? false,
                storageDevices: storageDevices?.map { $0.asStorageDevice() } ?? []
            )
        }

        private func mappedConsoleType(_ value: String?) -> ConsoleType {
            switch value {
            case "XboxSeriesX":
                return .xboxSeriesX
            case "XboxSeriesS":
                return .xboxSeriesS
            case "XboxOne":
                return .xboxOne
            case "XboxOneS":
                return .xboxOneS
            case "XboxOneX":
                return .xboxOneX
            default:
                return .unknown
            }
        }

        private func mappedPowerState(_ value: String?) -> ConsolePowerState {
            switch value {
            case "ConnectedStandby":
                return .connectedStandby
            case "On":
                return .on
            case "Off":
                return .off
            default:
                return .unknown
            }
        }
    }

    let status: ConsoleServiceStatus
    let result: [RemoteConsole]

    func assertOK() throws {
        guard status.errorCode == "OK" else {
            throw ConsoleRepositoryError.service(status.errorMessage ?? status.errorCode)
        }
    }
}

private struct ConsoleCommandResponse: Decodable {
    let status: ConsoleServiceStatus

    func assertOK() throws {
        guard status.errorCode == "OK" else {
            throw ConsoleRepositoryError.service(status.errorMessage ?? status.errorCode)
        }
    }
}

private struct ConsoleCommandRequest: Encodable {
    let destination: String
    let type: String
    let command: String
    let sessionID: String
    let sourceID: String
    let parameters: [ConsoleCommandValue]
    let linkedXboxID: String

    enum CodingKeys: String, CodingKey {
        case destination
        case type
        case command
        case sessionID = "sessionId"
        case sourceID = "sourceId"
        case parameters
        case linkedXboxID = "linkedXboxId"
    }
}

enum ConsoleCommandValue: Encodable {
    case string(String)
    case dictionary([String: ConsoleCommandValue])

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .string(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .dictionary(value):
            try value.encode(to: encoder)
        }
    }
}
