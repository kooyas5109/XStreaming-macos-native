import Testing
@testable import SharedDomain

@Test
func appLanguageNormalizesChineseLocaleCodes() {
    #expect(AppLanguage(localeCode: "zh-CN") == .simplifiedChinese)
    #expect(AppLanguage(localeCode: "zh-Hans") == .simplifiedChinese)
}

@Test
func appLanguageFallsBackToEnglishForUnknownLocaleCodes() {
    #expect(AppLanguage(localeCode: "en-US") == .english)
    #expect(AppLanguage(localeCode: "fr-FR") == .english)
}
