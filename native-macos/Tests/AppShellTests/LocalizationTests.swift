import PersistenceKit
import SharedDomain
import SettingsFeature
import Testing
@testable import AppShell

@MainActor
@Test
func localizationStoreLoadsSavedChineseLocale() throws {
    let settings = SettingsMapper.withUpdatedPreferences(
        from: .defaults,
        locale: AppLanguage.simplifiedChinese.localeCode,
        preferredGameLanguage: AppSettings.defaults.preferredGameLanguage,
        fullscreen: AppSettings.defaults.fullscreen,
        performanceStyle: AppSettings.defaults.performanceStyle,
        url: "",
        username: "",
        credential: ""
    )
    let store = InMemorySettingsStore(initialValue: settings)
    let localization = ShellLocalizationStore(settingsStore: store)

    localization.load()

    #expect(localization.language == AppLanguage.simplifiedChinese)
}
