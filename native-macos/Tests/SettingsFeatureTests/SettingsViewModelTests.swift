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

    try model.save()

    let persisted = try store.load()
    #expect(persisted.turnServer.url == "turn:relay.example.com")
    #expect(persisted.locale == "en")
    #expect(persisted.preferredGameLanguage == "zh-CN")
    #expect(persisted.fullscreen == true)
    #expect(persisted.performanceStyle == true)
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
    #expect(model.serverURL == "")
    #expect(model.toastMessage == "Reset")
}
