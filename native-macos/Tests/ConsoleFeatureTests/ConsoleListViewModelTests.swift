import Testing
@testable import ConsoleFeature

@MainActor
@Test
func consoleListLoadsCachedThenRemoteConsoles() async throws {
    let model = ConsoleListViewModel.preview()
    try await model.load()
    #expect(model.consoles.count == 2)
    #expect(model.isLoading == false)
}
