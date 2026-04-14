import SwiftUI
import SharedDomain

public struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel

    public init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ShellSectionHeader(
                    eyebrow: "Home",
                    title: "Console Library",
                    subtitle: "Launch into your local Xbox devices and preview the native macOS streaming flow."
                )

                HStack(spacing: 14) {
                    ShellMetricCard(
                        title: "Available Consoles",
                        value: "\(viewModel.consoles.count)",
                        icon: "display.2",
                        tint: .blue
                    )
                    ShellMetricCard(
                        title: "Ready To Stream",
                        value: "\(connectedStandbyCount)",
                        icon: "bolt.horizontal.circle",
                        tint: .green
                    )
                    ShellMetricCard(
                        title: "Preview Engine",
                        value: "Native",
                        icon: "sparkles.tv",
                        tint: .cyan
                    )
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                ShellPanel(
                    title: "Your Consoles",
                    subtitle: "Choose a device to open the current native stream preview surface."
                ) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.consoles, id: \.id) { console in
                            Button {
                                viewModel.openConsole(console)
                            } label: {
                                ConsoleRow(console: console)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .overlay {
                        if viewModel.isLoading {
                            ProgressView("Loading Consoles...")
                        } else if viewModel.consoles.isEmpty {
                            ContentUnavailableView(
                                "No Consoles",
                                systemImage: "xbox.logo",
                                description: Text("Connect an Xbox to start a native console stream.")
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
                    ShellStatusBadge(label: console.powerState.rawValue, tint: badgeTint)
                    Text(console.consoleType.rawValue)
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
