import SwiftUI

public struct RootView: View {
    private let environment: AppEnvironment
    @ObservedObject private var router: AppRouter

    public init(environment: AppEnvironment) {
        self.environment = environment
        _router = ObservedObject(wrappedValue: environment.router)
    }

    public var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("XStreaming")
                        .font(.title2.weight(.bold))
                    Text("Native macOS preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                List(selection: selectedRouteBinding) {
                    Label("Home", systemImage: "desktopcomputer")
                        .tag(AppRouter.Route.home)
                    Label("Cloud", systemImage: "icloud")
                        .tag(AppRouter.Route.cloud)
                    Label("Settings", systemImage: "gearshape")
                        .tag(AppRouter.Route.settings)
                }
                .listStyle(.sidebar)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview Stack")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(engineStatusLine)
                        .font(.callout)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.thinMaterial)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1100, minHeight: 720)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(currentTitle)
                        .font(.headline)
                    Text(currentSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            environment.logger.info("RootView loaded with route: \(String(describing: router.currentRoute))")
        }
    }

    private var currentTitle: String {
        switch router.currentRoute {
        case .home:
            return "Console Library"
        case .cloud:
            return "Cloud Catalog"
        case .settings:
            return "Settings"
        case .streamConsole:
            return "Console Stream"
        case .streamCloud:
            return "Cloud Stream"
        }
    }

    private var currentSubtitle: String {
        switch router.currentRoute {
        case .home:
            return "Browse your local Xbox devices"
        case .cloud:
            return "Pick a title and jump into preview streaming"
        case .settings:
            return "Adjust playback, TURN, and demo preferences"
        case .streamConsole(let id):
            return "Preview session for console \(id)"
        case .streamCloud(let id):
            return "Preview session for title \(id)"
        }
    }

    private var engineStatusLine: String {
        environment.streamingEngine.capabilities.supportsRumble
        ? "Native engine active"
        : "Compatibility engine active"
    }

    private var selectedRouteBinding: Binding<AppRouter.Route?> {
        Binding(
            get: {
                switch router.currentRoute {
                case .home, .cloud, .settings:
                    return router.currentRoute
                case .streamConsole:
                    return .home
                case .streamCloud:
                    return .cloud
                }
            },
            set: { route in
                guard let route else { return }
                router.route(to: route)
            }
        )
    }

    @ViewBuilder
    private var detailView: some View {
        switch router.currentRoute {
        case .home:
            HomeView(
                viewModel: HomeViewModel(
                    service: environment.consoleService,
                    router: router
                )
            )

        case .cloud:
            CloudView(
                service: environment.catalogService,
                router: router
            )

        case .settings:
            SettingsContainerView(settingsStore: environment.settingsStore)

        case .streamConsole(let id):
            StreamContainerView(
                route: .streamConsole(id: id),
                streamingService: environment.streamingService,
                engine: environment.streamingEngine,
                router: router
            )

        case .streamCloud(let id):
            StreamContainerView(
                route: .streamCloud(id: id),
                streamingService: environment.streamingService,
                engine: environment.streamingEngine,
                router: router
            )
        }
    }
}
