import Testing
@testable import AppShell

@MainActor
@Test
func selectingConsoleRoutesToStreamScreen() throws {
    let router = AppRouter()
    router.route(to: .streamConsole(id: "console-1"))
    #expect(router.currentRoute == .streamConsole(id: "console-1"))
}

@MainActor
@Test
func selectingCloudTitleRoutesToCloudStreamScreen() throws {
    let router = AppRouter()
    router.route(to: .streamCloud(id: "title-1"))
    #expect(router.currentRoute == .streamCloud(id: "title-1"))
}
