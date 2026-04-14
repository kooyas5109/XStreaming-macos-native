import SwiftUI

public struct RootView: View {
    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: selectedRouteBinding) {
                Label("Home", systemImage: "desktopcomputer")
                    .tag(AppRouter.Route.home)
                Label("Cloud", systemImage: "icloud")
                    .tag(AppRouter.Route.cloud)
                Label("Settings", systemImage: "gearshape")
                    .tag(AppRouter.Route.settings)
            }
            .listStyle(.sidebar)
        } detail: {
            detailView
        }
        .frame(minWidth: 1100, minHeight: 720)
        .task {
            environment.logger.info("RootView loaded with route: \(String(describing: environment.router.currentRoute))")
        }
    }

    private var selectedRouteBinding: Binding<AppRouter.Route?> {
        Binding(
            get: {
                switch environment.router.currentRoute {
                case .home, .cloud, .settings:
                    return environment.router.currentRoute
                case .streamConsole:
                    return .home
                case .streamCloud:
                    return .cloud
                }
            },
            set: { route in
                guard let route else { return }
                environment.router.route(to: route)
            }
        )
    }

    @ViewBuilder
    private var detailView: some View {
        switch environment.router.currentRoute {
        case .home:
            HomeView(
                viewModel: HomeViewModel(
                    service: environment.consoleService,
                    router: environment.router
                )
            )

        case .cloud:
            CloudView(
                service: environment.catalogService,
                router: environment.router
            )

        case .settings:
            SettingsContainerView(settingsStore: environment.settingsStore)

        case .streamConsole(let id):
            StreamContainerView(
                route: .streamConsole(id: id),
                streamingService: environment.streamingService,
                engine: environment.streamingEngine
            )

        case .streamCloud(let id):
            StreamContainerView(
                route: .streamCloud(id: id),
                streamingService: environment.streamingService,
                engine: environment.streamingEngine
            )
        }
    }
}
