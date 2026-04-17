import SharedDomain
import SwiftUI
import Testing
@testable import AppShell

@MainActor
@Test
func appLaunchSmokeBuildsPreviewEnvironmentAndRootView() {
    let environment = AppEnvironment.makePreview()
    let rootView = RootView(environment: environment)

    #expect(environment.router.currentRoute == .home)
    #expect(environment.streamingEngine.capabilities.supportsVideo == true)
    _ = rootView.body
}

@MainActor
@Test
func appLaunchSmokeSupportsPreviewNavigationAndStreamSurface() {
    let environment = AppEnvironment.makePreview()

    environment.router.route(to: .streamCloud(id: "title-1"))
    let streamView = StreamContainerView(
        route: .streamCloud(id: "title-1"),
        streamingService: environment.streamingService,
        consoleService: environment.consoleService,
        engine: environment.streamingEngine,
        router: environment.router,
        commandCenter: environment.streamCommandCenter,
        settingsStore: environment.settingsStore,
        language: .english
    )

    #expect(environment.router.currentRoute == .streamCloud(id: "title-1"))
    _ = streamView.body
}
