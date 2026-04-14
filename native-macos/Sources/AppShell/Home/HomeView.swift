import SwiftUI
import SharedDomain

public struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let language: AppLanguage

    public init(viewModel: HomeViewModel, language: AppLanguage) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.language = language
    }

    public var body: some View {
        let strings = ShellStrings(language: language)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ShellSectionHeader(
                    eyebrow: strings.homeEyebrow,
                    title: strings.homeTitle,
                    subtitle: strings.homeSubtitle
                )

                HStack(spacing: 14) {
                    ShellMetricCard(
                        title: strings.availableConsoles,
                        value: "\(viewModel.consoles.count)",
                        icon: "display.2",
                        tint: .blue
                    )
                    ShellMetricCard(
                        title: strings.readyToStream,
                        value: "\(connectedStandbyCount)",
                        icon: "bolt.horizontal.circle",
                        tint: .green
                    )
                    ShellMetricCard(
                        title: strings.previewEngine,
                        value: strings.nativeLabel,
                        icon: "sparkles.tv",
                        tint: .cyan
                    )
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                ShellPanel(
                    title: strings.yourConsoles,
                    subtitle: strings.yourConsolesSubtitle
                ) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.consoles, id: \.id) { console in
                            Button {
                                viewModel.openConsole(console)
                            } label: {
                                ConsoleRow(console: console, strings: strings)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .overlay {
                        if viewModel.isLoading {
                            ProgressView(strings.loadingConsoles)
                        } else if viewModel.consoles.isEmpty {
                            ContentUnavailableView(
                                strings.noConsoles,
                                systemImage: "xbox.logo",
                                description: Text(strings.noConsolesDescription)
                            )
                        }
                    }
                }
            }
            .padding(28)
        }
        .task {
            await viewModel.load()
        }
    }

    private var connectedStandbyCount: Int {
        viewModel.consoles.filter { $0.powerState == .connectedStandby || $0.powerState == .on }.count
    }
}

private struct ConsoleRow: View {
    let console: ConsoleDevice
    let strings: ShellStrings

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "display")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(console.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    ShellStatusBadge(label: strings.localizedPowerState(console.powerState), tint: badgeTint)
                    Text(strings.localizedConsoleType(console.consoleType))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "arrow.right.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private var badgeTint: Color {
        switch console.powerState {
        case .connectedStandby, .on:
            return .green
        case .off:
            return .orange
        case .unknown:
            return .secondary
        }
    }
}
