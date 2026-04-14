import Testing
@testable import CatalogFeature

@MainActor
@Test
func catalogViewModelLoadsPreviewCatalog() async throws {
    let model = CatalogViewModel.preview()
    try await model.load()
    #expect(model.titles.count == 2)
    #expect(model.displayedTitles.count == 1)
}
