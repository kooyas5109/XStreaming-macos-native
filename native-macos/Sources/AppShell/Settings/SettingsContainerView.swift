import PersistenceKit
import SharedDomain
import SettingsFeature
import SwiftUI

public struct SettingsContainerView: View {
    @StateObject private var viewModel: SettingsViewModel
    private let language: AppLanguage
    private let onSettingsChanged: ((AppSettings) -> Void)?

    public init(
        settingsStore: SettingsStoreProtocol,
        language: AppLanguage,
        onSettingsChanged: ((AppSettings) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(settingsStore: settingsStore))
        self.language = language
        self.onSettingsChanged = onSettingsChanged
    }

    public var body: some View {
        let strings = ShellStrings(language: language)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ShellSectionHeader(
                    eyebrow: strings.settingsEyebrow,
                    title: strings.settingsTitle,
                    subtitle: strings.settingsSubtitle
                )

                HStack(spacing: 14) {
                    ShellMetricCard(
                        title: strings.shellLanguage,
                        value: strings.languageStatusSummary,
                        icon: "character.bubble",
                        tint: .blue
                    )
                    ShellMetricCard(
                        title: strings.displayMode,
                        value: viewModel.launchesFullscreen ? strings.immersive : strings.windowed,
                        icon: "macwindow",
                        tint: .orange
                    )
                    ShellMetricCard(
                        title: strings.experience,
                        value: viewModel.performanceStyleEnabled ? strings.performance : strings.balanced,
                        icon: "speedometer",
                        tint: .green
                    )
                }

                ShellPanel(
                    title: strings.shellStatusTitle,
                    subtitle: strings.shellStatusSubtitle
                ) {
                    HStack(spacing: 12) {
                        ShellStatusBadge(label: strings.languageStatusSummary, tint: .blue)
                        ShellStatusBadge(
                            label: strings.localizedPreferredGameLanguage(viewModel.preferredGameLanguage),
                            tint: .secondary
                        )
                        ShellStatusBadge(
                            label: viewModel.serverURL.isEmpty ? strings.transportDefault : strings.customTurn,
                            tint: .purple
                        )

                        Spacer()
                    }
                }

                ShellPanel(
                    title: strings.relayPlaybackTitle,
                    subtitle: strings.relayPlaybackSubtitle
                ) {
                    SettingsView(viewModel: viewModel)
                        .padding(0)
                }
            }
            .padding(28)
        }
        .onChange(of: viewModel.settings) { _, settings in
            onSettingsChanged?(settings)
        }
    }
}
