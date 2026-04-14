import CatalogFeature
import SharedDomain
import SwiftUI

public struct CloudView: View {
    @StateObject private var viewModel: CatalogViewModel
    private let router: AppRouter

    public init(service: CatalogService, router: AppRouter) {
        _viewModel = StateObject(wrappedValue: CatalogViewModel(service: service))
        self.router = router
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ShellSectionHeader(
                    eyebrow: "Cloud",
                    title: "Cloud Gaming Catalog",
                    subtitle: "Browse a compact Game Pass style catalog and jump into the native preview stream."
                )

                HStack(spacing: 14) {
                    ShellMetricCard(
                        title: "Visible Titles",
                        value: "\(viewModel.displayedTitles.count)",
                        icon: "square.stack.3d.up.fill",
                        tint: .blue
                    )
                    ShellMetricCard(
                        title: "Recently Played",
                        value: "\(viewModel.recentTitles.count)",
                        icon: "clock.arrow.circlepath",
                        tint: .orange
                    )
                    ShellMetricCard(
                        title: "Keyboard Support",
                        value: "\(keyboardReadyCount)",
                        icon: "keyboard",
                        tint: .green
                    )
                }

                ShellPanel(
                    title: "Browse Titles",
                    subtitle: "Switch between recently played, newest arrivals, and the full preview catalog."
                ) {
                    Picker("Catalog", selection: $viewModel.currentTab) {
                        Text("Recently").tag(CatalogTab.recently)
                        Text("Newest").tag(CatalogTab.newest)
                        Text("All").tag(CatalogTab.all)
                    }
                    .pickerStyle(.segmented)

                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.displayedTitles, id: \.productID) { title in
                            Button {
                                router.route(to: .streamCloud(id: title.productID))
                            } label: {
                                CloudTitleRow(title: title)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .overlay {
                        if viewModel.isLoading {
                            ProgressView("Loading Catalog...")
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .padding(28)
        }
        .task {
            try? await viewModel.load()
        }
    }

    private var keyboardReadyCount: Int {
        viewModel.displayedTitles.filter { $0.supportedInputTypes.contains(.mouseAndKeyboard) }.count
    }
}

private struct CloudTitleRow: View {
    let title: CatalogTitle

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.7), .cyan.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "play.rectangle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title.productTitle)
                    .font(.headline)

                Text(title.publisherName)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(title.supportedInputTypes, id: \.self) { input in
                        ShellStatusBadge(label: input.rawValue, tint: input == .mouseAndKeyboard ? .green : .blue)
                    }
                }
            }

            Spacer()

            Image(systemName: "arrow.right.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
}
