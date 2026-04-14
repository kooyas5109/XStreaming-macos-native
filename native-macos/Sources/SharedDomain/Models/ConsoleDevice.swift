import Foundation

public enum ConsoleType: String, Codable, Equatable, Sendable, CaseIterable {
    case xboxSeriesX
    case xboxSeriesS
    case xboxOne
    case xboxOneS
    case xboxOneX
    case unknown
}

public enum ConsolePowerState: String, Codable, Equatable, Sendable, CaseIterable {
    case connectedStandby
    case on
    case off
    case unknown
}

public struct StorageDevice: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let isDefault: Bool
    public let freeSpaceBytes: Int64
    public let totalSpaceBytes: Int64
    public let isGen9Compatible: Bool?

    public init(
        id: String,
        name: String,
        isDefault: Bool,
        freeSpaceBytes: Int64,
        totalSpaceBytes: Int64,
        isGen9Compatible: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.freeSpaceBytes = freeSpaceBytes
        self.totalSpaceBytes = totalSpaceBytes
        self.isGen9Compatible = isGen9Compatible
    }
}

public struct ConsoleDevice: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let locale: String
    public let region: String
    public let consoleType: ConsoleType
    public let powerState: ConsolePowerState
    public let remoteManagementEnabled: Bool
    public let consoleStreamingEnabled: Bool
    public let wirelessWarning: Bool
    public let outOfHomeWarning: Bool
    public let storageDevices: [StorageDevice]

    public init(
        id: String,
        name: String,
        locale: String = "",
        region: String = "",
        consoleType: ConsoleType = .unknown,
        powerState: ConsolePowerState = .unknown,
        remoteManagementEnabled: Bool = false,
        consoleStreamingEnabled: Bool = false,
        wirelessWarning: Bool = false,
        outOfHomeWarning: Bool = false,
        storageDevices: [StorageDevice] = []
    ) {
        self.id = id
        self.name = name
        self.locale = locale
        self.region = region
        self.consoleType = consoleType
        self.powerState = powerState
        self.remoteManagementEnabled = remoteManagementEnabled
        self.consoleStreamingEnabled = consoleStreamingEnabled
        self.wirelessWarning = wirelessWarning
        self.outOfHomeWarning = outOfHomeWarning
        self.storageDevices = storageDevices
    }
}
