import PersistenceKit
import SharedDomain
import Testing
@testable import SettingsFeature

@MainActor
@Test
func savingTurnServerUpdatesSettingsStore() async throws {
    let store = InMemorySettingsStore()
    let model = SettingsViewModel(settingsStore: store)
    try model.load()

    model.serverURL = "turn:relay.example.com"
    model.serverUsername = "user"
    model.serverCredential = "secret"
    model.preferredGameLanguage = "zh-CN"
    model.launchesFullscreen = true
    model.performanceStyleEnabled = true
    model.resolution = 1080
    model.videoFormat = "Stretch"
    model.hostBitrate = 28
    model.cloudBitrate = 24
    model.audioBitrate = 18

    try model.save()

    let persisted = try store.load()
    #expect(persisted.turnServer.url == "turn:relay.example.com")
    #expect(persisted.locale == "en")
    #expect(persisted.preferredGameLanguage == "zh-CN")
    #expect(persisted.fullscreen == true)
    #expect(persisted.performanceStyle == true)
    #expect(persisted.resolution == 1080)
    #expect(persisted.videoFormat == "Stretch")
    #expect(persisted.xhomeBitrate == 28)
    #expect(persisted.xcloudBitrate == 24)
    #expect(persisted.audioBitrate == 18)
    #expect(model.toastMessage == "Saved")
}

@MainActor
@Test
func savingLanguageSelectionPersistsLocale() throws {
    let store = InMemorySettingsStore()
    let model = SettingsViewModel(settingsStore: store)
    try model.load()

    model.selectedLanguage = .simplifiedChinese
    try model.save()

    let persisted = try store.load()
    #expect(persisted.locale == AppLanguage.simplifiedChinese.localeCode)
    #expect(model.toastMessage == "已保存")
}

@MainActor
@Test
func savingInvalidTurnServerShowsValidationError() throws {
    let store = InMemorySettingsStore()
    let model = SettingsViewModel(settingsStore: store)
    try model.load()

    model.serverURL = "https://invalid.example.com"
    try model.save()

    #expect(model.errorMessage == "TURN server URL must start with turn:")
}

@MainActor
@Test
func resetRestoresDefaultSettings() throws {
    let store = InMemorySettingsStore(initialValue: SettingsMapper.withUpdatedPreferences(
        from: .defaults,
        locale: AppLanguage.simplifiedChinese.localeCode,
        preferredGameLanguage: "zh-CN",
        fullscreen: true,
        performanceStyle: true,
        url: "turn:relay.example.com",
        username: "user",
        credential: "secret"
    ))
    let model = SettingsViewModel(settingsStore: store)
    try model.load()

    try model.reset()

    #expect(model.settings == .defaults)
    #expect(model.selectedLanguage == .english)
    #expect(model.preferredGameLanguage == "en-US")
    #expect(model.launchesFullscreen == false)
    #expect(model.performanceStyleEnabled == false)
    #expect(model.resolution == 720)
    #expect(model.videoFormat == "")
    #expect(model.hostBitrate == 20)
    #expect(model.cloudBitrate == 20)
    #expect(model.audioBitrate == 20)
    #expect(model.serverURL == "")
    #expect(model.toastMessage == "Reset")
}

@Test
func settingsMapperUpdatesDisplayOptionsWithoutTouchingLocale() {
    let displayOptions = DisplayOptions(sharpness: 9, saturation: 130, contrast: 120, brightness: 110)

    let updated = SettingsMapper.withUpdatedDisplayOptions(
        from: .defaults,
        displayOptions: displayOptions
    )

    #expect(updated.displayOptions == displayOptions)
    #expect(updated.locale == AppSettings.defaults.locale)
}

@Test
func settingsMapperUpdatesStreamingPreferencesWithoutTouchingLanguage() {
    let updated = SettingsMapper.withUpdatedStreamingPreferences(
        from: .defaults,
        resolution: 1081,
        videoFormat: "Zoom",
        xhomeBitrate: 30,
        xcloudBitrate: 26,
        audioBitrate: 22
    )

    #expect(updated.resolution == 1081)
    #expect(updated.videoFormat == "Zoom")
    #expect(updated.xhomeBitrate == 30)
    #expect(updated.xcloudBitrate == 26)
    #expect(updated.audioBitrate == 22)
    #expect(updated.locale == AppSettings.defaults.locale)
}
