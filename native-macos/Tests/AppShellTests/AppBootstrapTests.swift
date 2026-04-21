import Testing
import PersistenceKit
@testable import AppShell

@MainActor
@Test
func appEnvironmentBuildsDefaultDependencies() throws {
    let environment = AppEnvironment.makePreview()
    #expect(environment.router.currentRoute == .home)
    #expect(environment.authMode == .preview)
}

@MainActor
@Test
func liveAppEnvironmentUsesCompatibilityStreamingSurface() throws {
    let environment = AppEnvironment.make(mode: .live)

    #expect(environment.authMode == .live)
    #expect(String(describing: type(of: environment.streamingEngine)).contains("WebViewStreamingEngine"))
    #expect(environment.settingsStore is UserDefaultsSettingsStore)
}
