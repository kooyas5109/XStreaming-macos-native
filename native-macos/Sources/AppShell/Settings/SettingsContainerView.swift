import PersistenceKit
import SettingsFeature
import SwiftUI

public struct SettingsContainerView: View {
    @StateObject private var viewModel: SettingsViewModel

    public init(settingsStore: SettingsStoreProtocol) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(settingsStore: settingsStore))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ShellSectionHeader(
                    eyebrow: "Settings",
                    title: "Streaming Preferences",
                    subtitle: "Tune TURN relay details and demo playback options for the native preview shell."
                )

                HStack(spacing: 14) {
                    ShellMetricCard(
                        title: "Transport",
                        value: viewModel.serverURL.isEmpty ? "Default" : "Custom TURN",
                        icon: "network",
                        tint: .purple
                    )
                    ShellMetricCard(
                        title: "Audio",
                        value: viewModel.settings.enableAudioControl ? "Managed" : "Auto",
                        icon: "speaker.wave.2.fill",
                        tint: .orange
                    )
                    ShellMetricCard(
                        title: "Rumble",
                        value: viewModel.settings.vibration ? "Enabled" : "Disabled",
                        icon: "gamecontroller.fill",
                        tint: .green
                    )
                }

                ShellPanel(
                    title: "Relay And Playback",
                    subtitle: "These controls already write through the typed settings store and are ready for live migration work."
                ) {
                    SettingsView(viewModel: viewModel)
                        .padding(0)
                }
            }
            .padding(28)
        }
    }
}
