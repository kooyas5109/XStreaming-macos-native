import SwiftUI

public struct RootView: View {
    private let environment: AppEnvironment
    @ObservedObject private var router: AppRouter
    @StateObject private var localization: ShellLocalizationStore

    public init(environment: AppEnvironment) {
        self.environment = environment
        _router = ObservedObject(wrappedValue: environment.router)
        _localization = StateObject(wrappedValue: ShellLocalizationStore(settingsStore: environment.settingsStore))
    }

    public var body: some View {
        let strings = ShellStrings(language: localization.language)

        NavigationSplitView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("XStreaming")
                        .font(.title2.weight(.bold))
                    Text(strings.appSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                List(selection: selectedRouteBinding) {
                    Label(strings.homeTab, systemImage: "desktopcomputer")
                        .tag(AppRouter.Route.home)
                    Label(strings.cloudTab, systemImage: "icloud")
                        .tag(AppRouter.Route.cloud)
                    Label(strings.settingsTab, systemImage: "gearshape")
                        .tag(AppRouter.Route.settings)
                }
                .listStyle(.sidebar)

                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.previewStackTitle)
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
                    Text(strings.rootTitle(for: router.currentRoute))
                        .font(.headline)
                    Text(strings.rootSubtitle(for: router.currentRoute))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ToolbarItemGroup(placement: .automatic) {
                ShellToolbarBadge(
                    label: strings.shellLanguage,
                    value: strings.languageBadgeTitle,
                    icon: "character.bubble",
                    tint: .blue
                )

                ShellToolbarBadge(
                    label: strings.engine,
                    value: environment.streamingEngine.capabilities.supportsRumble ? strings.nativeLabel : strings.compatibilityLabel,
                    icon: "sparkles.tv",
                    tint: .cyan
                )

                if router.currentRoute != .settings {
                    Button {
                        router.route(to: .settings)
                    } label: {
                        Label(strings.openSettingsAction, systemImage: "slider.horizontal.3")
                    }
                }
            }
        }
        .task {
            localization.load()
            environment.logger.info("RootView loaded with route: \(String(describing: router.currentRoute))")
        }
    }

    private var engineStatusLine: String {
        let strings = ShellStrings(language: localization.language)
        return environment.streamingEngine.capabilities.supportsRumble
        ? strings.nativeEngineActive
        : strings.compatibilityEngineActive
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
                viewModel: HomeViewModel(service: environment.consoleService, router: router),
                language: localization.language
            )

        case .cloud:
            CloudView(
                service: environment.catalogService,
                router: router,
                language: localization.language
            )

        case .settings:
            SettingsContainerView(
                settingsStore: environment.settingsStore,
                language: localization.language,
                onSettingsChanged: { settings in
                    localization.apply(settings: settings)
                }
            )

        case .streamConsole(let id):
            StreamContainerView(
                route: .streamConsole(id: id),
                streamingService: environment.streamingService,
                engine: environment.streamingEngine,
                router: router,
                language: localization.language
            )

        case .streamCloud(let id):
            StreamContainerView(
                route: .streamCloud(id: id),
                streamingService: environment.streamingService,
                engine: environment.streamingEngine,
                router: router,
                language: localization.language
            )
        }
    }
}
