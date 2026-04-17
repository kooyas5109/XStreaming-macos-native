import PersistenceKit
import SharedDomain
import SettingsFeature
import Testing
@testable import AppShell

@MainActor
@Test
func localizationStoreDefaultsToChineseOnFirstLaunch() {
    let store = InMemorySettingsStore()
    let localization = ShellLocalizationStore(settingsStore: store)

    localization.load()

    #expect(localization.language == AppLanguage.simplifiedChinese)
}

@MainActor
@Test
func homeShellCopyDoesNotEmphasizeNativeEngine() {
    let strings = ShellStrings(language: .simplifiedChinese)

    #expect(strings.appSubtitle == "macOS 预览版")
    #expect(strings.previewStackTitle == "串流状态")
    #expect(strings.nativeEngineActive == "已就绪")
    #expect(strings.homeSubtitle.contains("原生") == false)
    #expect(strings.yourConsolesSubtitle.contains("原生") == false)
}

@MainActor
@Test
func streamShellCopyDoesNotDescribeLiveFlowAsPreview() {
    let strings = ShellStrings(language: .simplifiedChinese)

    #expect(strings.startPreviewStream == "开始串流")
    #expect(strings.streamSubtitle.contains("真实 Xbox 串流会话"))
    #expect(strings.streamHelpText(for: .idle) == "点击开始以创建串流会话。")
    #expect(strings.nexusPressSuccess.contains("预览") == false)
}

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
