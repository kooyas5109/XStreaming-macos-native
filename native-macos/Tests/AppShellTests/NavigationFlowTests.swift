import Testing
import SharedDomain
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

@Test
func cloudTitleStreamingTargetUsesTitleIDNotProductID() {
    let title = CatalogTitle(
        titleID: "9N123ABC",
        productID: "BT5P2X999VH2",
        productTitle: "Cloud Game"
    )

    #expect(title.cloudStreamingTargetID == "9N123ABC")
}
