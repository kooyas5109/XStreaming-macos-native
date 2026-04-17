import Foundation
import Testing
@testable import SharedDomain

@Test
func appSettingsDefaultsToChineseLocale() {
    #expect(AppSettings.defaults.locale == AppLanguage.simplifiedChinese.localeCode)
}

@Test
func appSettingsRoundTripsThroughJSON() throws {
    let value = AppSettings.defaults
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
    #expect(decoded == value)
}

@Test
func consoleDeviceRoundTripsThroughJSON() throws {
    let value = ConsoleDevice(
        id: "console-1",
        name: "Living Room Xbox",
        locale: "en-US",
        region: "US",
        consoleType: .xboxSeriesX,
        powerState: .connectedStandby,
        remoteManagementEnabled: true,
        consoleStreamingEnabled: true,
        wirelessWarning: false,
        outOfHomeWarning: false,
        storageDevices: [
            StorageDevice(
                id: "disk-1",
                name: "Internal",
                isDefault: true,
                freeSpaceBytes: 100,
                totalSpaceBytes: 1000,
                isGen9Compatible: true
            )
        ]
    )
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(ConsoleDevice.self, from: data)
    #expect(decoded == value)
}

@Test
func streamingSessionRoundTripsThroughJSON() throws {
    let value = StreamingSession(
        id: "session-1",
        targetID: "target-1",
        sessionPath: "/v5/sessions/cloud/session-1",
        kind: .cloud,
        state: .queued,
        waitingTimeMinutes: 12,
        errorDetails: StreamingErrorDetails(code: "none", message: "queued")
    )
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(StreamingSession.self, from: data)
    #expect(decoded == value)
}
