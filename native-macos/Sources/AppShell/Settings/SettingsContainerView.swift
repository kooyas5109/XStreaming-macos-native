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
                        title: strings.transport,
                        value: viewModel.serverURL.isEmpty ? strings.transportDefault : strings.customTurn,
                        icon: "network",
                        tint: .purple
                    )
                    ShellMetricCard(
                        title: strings.audio,
                        value: viewModel.settings.enableAudioControl ? strings.managed : strings.auto,
                        icon: "speaker.wave.2.fill",
                        tint: .orange
                    )
                    ShellMetricCard(
                        title: strings.rumble,
                        value: viewModel.settings.vibration ? strings.enabled : strings.disabled,
                        icon: "gamecontroller.fill",
                        tint: .green
                    )
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
