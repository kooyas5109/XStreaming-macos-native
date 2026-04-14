import Combine
import ConsoleFeature
import SharedDomain

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var consoles: [ConsoleDevice] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let service: ConsoleService
    private let router: AppRouter

    public init(service: ConsoleService, router: AppRouter) {
        self.service = service
        self.router = router
    }

    public func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await service.loadConsoles()
            consoles = result.remote.isEmpty ? result.cached : result.remote
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    public func openConsole(_ console: ConsoleDevice) {
        router.route(to: .streamConsole(id: console.id))
    }

    public func refresh() async {
        await load()
    }
}
