import CatalogFeature
import SwiftUI

public struct CloudView: View {
    @StateObject private var viewModel: CatalogViewModel
    private let router: AppRouter

    public init(service: CatalogService, router: AppRouter) {
        _viewModel = StateObject(wrappedValue: CatalogViewModel(service: service))
        self.router = router
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cloud Gaming")
                .font(.largeTitle.weight(.semibold))

            Picker("Catalog", selection: $viewModel.currentTab) {
                Text("Recently").tag(CatalogTab.recently)
                Text("Newest").tag(CatalogTab.newest)
                Text("All").tag(CatalogTab.all)
            }
            .pickerStyle(.segmented)

            List(viewModel.displayedTitles, id: \.productID) { title in
                Button {
                    router.route(to: .streamCloud(id: title.productID))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title.productTitle)
                            .font(.headline)
                        Text(title.publisherName)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading Catalog...")
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .task {
            try? await viewModel.load()
        }
    }
}
