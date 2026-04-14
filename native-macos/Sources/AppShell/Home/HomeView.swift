import SwiftUI
import SharedDomain

public struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel

    public init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Consoles")
                .font(.largeTitle.weight(.semibold))

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            List(viewModel.consoles, id: \.id) { console in
                Button {
                    viewModel.openConsole(console)
                } label: {
                    ConsoleRow(console: console)
                }
                .buttonStyle(.plain)
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
        .padding()
        .task {
            await viewModel.load()
        }
    }
}

private struct ConsoleRow: View {
    let console: ConsoleDevice

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "display")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(console.name)
                    .font(.headline)
                Text(console.powerState.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Open")
                .font(.callout.weight(.medium))
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 4)
    }
}
