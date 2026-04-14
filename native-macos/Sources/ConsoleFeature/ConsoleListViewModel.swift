import Combine
import SharedDomain

@MainActor
public final class ConsoleListViewModel: ObservableObject {
    @Published public private(set) var consoles: [ConsoleDevice] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let service: ConsoleService

    public init(service: ConsoleService) {
        self.service = service
    }

    public func load() async throws {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await service.loadConsoles()
            if result.cached.isEmpty == false {
                consoles = result.cached
            }
            consoles = result.remote
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public static func preview() -> ConsoleListViewModel {
        ConsoleListViewModel(service: .preview())
    }
}
