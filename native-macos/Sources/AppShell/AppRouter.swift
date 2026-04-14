import Foundation

@MainActor
public final class AppRouter {
    public enum Route: Equatable, Sendable {
        case home
    }

    public private(set) var currentRoute: Route

    public init(initialRoute: Route = .home) {
        self.currentRoute = initialRoute
    }

    public func route(to route: Route) {
        currentRoute = route
    }
}
