import CatalogFeature
import SharedDomain
import SwiftUI

public struct CloudView: View {
    @StateObject private var viewModel: CatalogViewModel
    private let router: AppRouter
    private let language: AppLanguage

    public init(service: CatalogService, router: AppRouter, language: AppLanguage) {
        _viewModel = StateObject(wrappedValue: CatalogViewModel(service: service))
        self.router = router
        self.language = language
    }

    public var body: some View {
        let strings = ShellStrings(language: language)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ShellSectionHeader(
                    eyebrow: strings.cloudEyebrow,
                    title: strings.cloudTitle,
                    subtitle: strings.cloudSubtitle
                )

                HStack(spacing: 14) {
                    ShellMetricCard(
                        title: strings.visibleTitles,
                        value: "\(viewModel.displayedTitles.count)",
                        icon: "square.stack.3d.up.fill",
                        tint: .blue
                    )
                    ShellMetricCard(
                        title: strings.recentlyPlayed,
                        value: "\(viewModel.recentTitles.count)",
                        icon: "clock.arrow.circlepath",
                        tint: .orange
                    )
                    ShellMetricCard(
                        title: strings.keyboardSupport,
                        value: "\(keyboardReadyCount)",
                        icon: "keyboard",
                        tint: .green
                    )
                }

                ShellPanel(
                    title: strings.browseTitles,
                    subtitle: strings.browseTitlesSubtitle
                ) {
                    HStack {
                        Spacer()

                        Button(strings.refreshAction) {
                            Task {
                                await viewModel.refresh()
                            }
                        }
                    }

                    Picker(strings.catalogPickerLabel, selection: $viewModel.currentTab) {
                        Text(strings.catalogRecently).tag(CatalogTab.recently)
                        Text(strings.catalogNewest).tag(CatalogTab.newest)
                        Text(strings.catalogAll).tag(CatalogTab.all)
                    }
                    .pickerStyle(.segmented)

                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.displayedTitles, id: \.productID) { title in
                            Button {
                                router.route(to: .streamCloud(id: title.productID))
                            } label: {
                                CloudTitleRow(title: title, strings: strings)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .overlay {
                        if viewModel.isLoading {
                            ProgressView(strings.loadingCatalog)
                        } else if viewModel.displayedTitles.isEmpty {
                            ContentUnavailableView(
                                strings.catalogEmptyTitle,
                                systemImage: "square.stack.3d.up.slash.fill",
                                description: Text(strings.catalogEmptyDescription)
                            )
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    HStack(spacing: 12) {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                        Button(strings.retryAction) {
                            Task {
                                await viewModel.refresh()
                            }
                        }
                    }
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
    let strings: ShellStrings

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
                        ShellStatusBadge(label: strings.localizedInputType(input), tint: input == .mouseAndKeyboard ? .green : .blue)
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
