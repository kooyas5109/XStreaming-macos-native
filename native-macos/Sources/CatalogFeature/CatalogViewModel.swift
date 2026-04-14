import Combine
import SharedDomain

public enum CatalogTab: String, CaseIterable, Equatable, Sendable {
    case recently
    case newest
    case all
}

@MainActor
public final class CatalogViewModel: ObservableObject {
    @Published public private(set) var titles: [CatalogTitle] = []
    @Published public private(set) var recentTitles: [CatalogTitle] = []
    @Published public private(set) var newTitles: [CatalogTitle] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public var currentTab: CatalogTab = .recently

    private let service: CatalogService

    public init(service: CatalogService) {
        self.service = service
    }

    public func load() async throws {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await service.loadCatalog()
            if result.cachedTitles.isEmpty == false {
                titles = result.cachedTitles
            }
            titles = result.titles
            recentTitles = result.recentTitles
            newTitles = result.newTitles
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public var displayedTitles: [CatalogTitle] {
        switch currentTab {
        case .recently:
            return recentTitles
        case .newest:
            return newTitles
        case .all:
            return titles
        }
    }

    public static func preview() -> CatalogViewModel {
        CatalogViewModel(service: .preview())
    }
}
