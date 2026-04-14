import PersistenceKit
import SettingsFeature
import SwiftUI

public struct SettingsContainerView: View {
    @StateObject private var viewModel: SettingsViewModel

    public init(settingsStore: SettingsStoreProtocol) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(settingsStore: settingsStore))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.largeTitle.weight(.semibold))

            SettingsView(viewModel: viewModel)
        }
        .padding()
    }
}
