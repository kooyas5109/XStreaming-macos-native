import SwiftUI

public struct ConsoleListView: View {
    @StateObject private var viewModel: ConsoleListViewModel

    public init(viewModel: ConsoleListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        List(viewModel.consoles, id: \.id) { console in
            VStack(alignment: .leading, spacing: 4) {
                Text(console.name)
                    .font(.headline)
                Text(console.powerState.rawValue)
                    .foregroundStyle(.secondary)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading Consoles...")
            }
        }
        .task {
            try? await viewModel.load()
        }
    }
}
