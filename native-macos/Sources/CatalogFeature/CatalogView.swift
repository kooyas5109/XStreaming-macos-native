import SwiftUI

public struct CatalogView: View {
    @StateObject private var viewModel: CatalogViewModel

    public init(viewModel: CatalogViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Catalog", selection: $viewModel.currentTab) {
                Text("Recently").tag(CatalogTab.recently)
                Text("Newest").tag(CatalogTab.newest)
                Text("All").tag(CatalogTab.all)
            }
            .pickerStyle(.segmented)

            List(viewModel.displayedTitles, id: \.productID) { title in
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.productTitle)
                        .font(.headline)
                    Text(title.publisherName)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading Catalog...")
            }
        }
        .padding()
        .task {
            try? await viewModel.load()
        }
    }
}
