import Testing
@testable import AppShell

@MainActor
@Test
func appEnvironmentBuildsDefaultDependencies() throws {
    let environment = AppEnvironment.makePreview()
    #expect(environment.router.currentRoute == .home)
    #expect(environment.authMode == .preview)
}
