import SwiftUI
import AuthFeature

public struct RootView: View {
    private let environment: AppEnvironment
    @ObservedObject private var router: AppRouter
    @StateObject private var localization: ShellLocalizationStore
    @StateObject private var authViewModel: AuthViewModel
    @State private var showAuthSheet = false

    public init(environment: AppEnvironment) {
        self.environment = environment
        _router = ObservedObject(wrappedValue: environment.router)
        _localization = StateObject(wrappedValue: ShellLocalizationStore(settingsStore: environment.settingsStore))
        _authViewModel = StateObject(wrappedValue: AuthViewModel(service: environment.authService))
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

                authStatusCard(strings: strings)
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

                ShellToolbarBadge(
                    label: strings.authModeTitle,
                    value: authModeLabel(strings: strings),
                    icon: "person.badge.key",
                    tint: environment.authMode == .live ? .green : .secondary
                )

                Button {
                    showAuthSheet = true
                } label: {
                    Label(
                        authViewModel.state.authState.isSignedIn ? strings.accountSignedIn : strings.accountSignedOut,
                        systemImage: authViewModel.state.authState.isSignedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.exclamationmark"
                    )
                }

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
            await authViewModel.restoreSession()
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthView(
                viewModel: authViewModel,
                language: localization.language,
                onSignedIn: {
                    showAuthSheet = false
                }
            )
                .frame(minWidth: 480, minHeight: 260)
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
                commandCenter: environment.streamCommandCenter,
                settingsStore: environment.settingsStore,
                language: localization.language
            )

        case .streamCloud(let id):
            StreamContainerView(
                route: .streamCloud(id: id),
                streamingService: environment.streamingService,
                engine: environment.streamingEngine,
                router: router,
                commandCenter: environment.streamCommandCenter,
                settingsStore: environment.settingsStore,
                language: localization.language
            )
        }
    }

    @ViewBuilder
    private func authStatusCard(strings: ShellStrings) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(strings.accountTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(authViewModel.state.authState.isSignedIn ? strings.accountSignedIn : strings.accountSignedOut)
                .font(.callout.weight(.semibold))

            if let gamertag = authViewModel.state.authState.userProfile?.gamertag, gamertag.isEmpty == false {
                Text(gamertag)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let statusMessage = authViewModel.state.authState.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                showAuthSheet = true
            } label: {
                Label(strings.manageAccountAction, systemImage: "person.crop.circle")
            }

            Text("\(strings.authModeTitle): \(authModeLabel(strings: strings))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private func authModeLabel(strings: ShellStrings) -> String {
        switch environment.authMode {
        case .preview:
            return strings.authModePreview
        case .live:
            return strings.authModeLive
        }
    }
}
