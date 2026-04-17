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
    model.codec = "video/H264-4d"
    model.hostBitrate = 28
    model.cloudBitrate = 24
    model.audioBitrate = 18
    model.vibrationEnabled = false
    model.nativeMouseKeyboardEnabled = true
    model.mouseSensitivity = 1.4

    try model.save()

    let persisted = try store.load()
    #expect(persisted.turnServer.url == "turn:relay.example.com")
    #expect(persisted.locale == AppLanguage.simplifiedChinese.localeCode)
    #expect(persisted.preferredGameLanguage == "zh-CN")
    #expect(persisted.fullscreen == true)
    #expect(persisted.performanceStyle == true)
    #expect(persisted.resolution == 1080)
    #expect(persisted.videoFormat == "Stretch")
    #expect(persisted.codec == "video/H264-4d")
    #expect(persisted.xhomeBitrate == 28)
    #expect(persisted.xcloudBitrate == 24)
    #expect(persisted.audioBitrate == 18)
    #expect(persisted.vibration == false)
    #expect(persisted.enableNativeMouseKeyboard == true)
    #expect(persisted.mouseSensitive == 1.4)
    #expect(model.toastMessage == "已保存")
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

    #expect(model.errorMessage == "TURN 服务器地址必须以 turn: 开头")
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
    #expect(model.selectedLanguage == .simplifiedChinese)
    #expect(model.preferredGameLanguage == "en-US")
    #expect(model.launchesFullscreen == false)
    #expect(model.performanceStyleEnabled == false)
    #expect(model.resolution == 720)
    #expect(model.videoFormat == "")
    #expect(model.codec == "")
    #expect(model.hostBitrate == 20)
    #expect(model.cloudBitrate == 20)
    #expect(model.audioBitrate == 20)
    #expect(model.vibrationEnabled == true)
    #expect(model.nativeMouseKeyboardEnabled == false)
    #expect(model.mouseSensitivity == 0.5)
    #expect(model.serverURL == "")
    #expect(model.toastMessage == "已重置")
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
        codec: "video/H264-42e",
        xhomeBitrate: 30,
        xcloudBitrate: 26,
        audioBitrate: 22,
        vibration: false,
        enableNativeMouseKeyboard: true,
        mouseSensitive: 1.1
    )

    #expect(updated.resolution == 1081)
    #expect(updated.videoFormat == "Zoom")
    #expect(updated.codec == "video/H264-42e")
    #expect(updated.xhomeBitrate == 30)
    #expect(updated.xcloudBitrate == 26)
    #expect(updated.audioBitrate == 22)
    #expect(updated.vibration == false)
    #expect(updated.enableNativeMouseKeyboard == true)
    #expect(updated.mouseSensitive == 1.1)
    #expect(updated.locale == AppSettings.defaults.locale)
}
