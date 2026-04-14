import Foundation
import SharedDomain
import Testing
@testable import PersistenceKit

@Test
func settingsStoreReturnsDefaultsOnFirstLaunch() throws {
    let store = InMemorySettingsStore()
    #expect(try store.load() == .defaults)
}

@Test
func userDefaultsSettingsStorePersistsValues() throws {
    let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let store = UserDefaultsSettingsStore(userDefaults: defaults, key: "settings")
    let updated = AppSettings(
        locale: "zh",
        useMSAL: true,
        fullscreen: true,
        resolution: 1080,
        xhomeAutoConnectServerID: "console-1",
        xhomeBitrateMode: "Custom",
        xhomeBitrate: 25,
        xcloudBitrateMode: "Auto",
        xcloudBitrate: 20,
        audioBitrateMode: "Auto",
        audioBitrate: 20,
        enableAudioControl: true,
        enableAudioRumble: false,
        audioRumbleThreshold: 0.15,
        preferredGameLanguage: "zh-CN",
        forceRegionIP: "1.1.1.1",
        codec: "video/H264",
        pollingRate: 500,
        coop: false,
        vibration: true,
        vibrationMode: "Native",
        gamepadKernel: "Native",
        gamepadMix: false,
        gamepadIndex: 0,
        deadZone: 0.2,
        edgeCompensation: 1,
        forceTriggerRumble: "always",
        powerOn: true,
        videoFormat: "hq",
        virtualGamepadOpacity: 0.7,
        ipv6: true,
        enableNativeMouseKeyboard: true,
        mouseSensitive: 0.9,
        performanceStyle: true,
        turnServer: TurnServerConfiguration(url: "turn:relay.example.com", username: "user", credential: "secret"),
        backgroundKeepalive: true,
        inputMouseKeyboardMapping: AppSettings.defaults.inputMouseKeyboardMapping,
        displayOptions: AppSettings.defaults.displayOptions,
        useVulkan: true,
        fsr: true,
        fsrSharpness: 3,
        debug: true
    )

    try store.save(updated)
    #expect(try store.load() == updated)
}
