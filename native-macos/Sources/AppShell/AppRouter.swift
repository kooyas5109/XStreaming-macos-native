import Foundation

@MainActor
public final class AppRouter {
    public enum Route: Hashable, Sendable {
        case home
        case cloud
        case settings
        case streamConsole(id: String)
        case streamCloud(id: String)
    }

    public private(set) var currentRoute: Route

    public init(initialRoute: Route = .home) {
        self.currentRoute = initialRoute
    }

    public func route(to route: Route) {
        currentRoute = route
    }
}
