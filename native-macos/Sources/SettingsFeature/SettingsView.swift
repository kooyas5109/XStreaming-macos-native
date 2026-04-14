import SwiftUI

public struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        Form {
            Section("TURN Server") {
                TextField("turn:relay.example.com", text: $viewModel.serverURL)
                TextField("Username", text: $viewModel.serverUsername)
                SecureField("Credential", text: $viewModel.serverCredential)
            }

            Section("Actions") {
                Button("Save") {
                    try? viewModel.save()
                }

                Button("Reset") {
                    try? viewModel.reset()
                }
            }

            if let toastMessage = viewModel.toastMessage {
                Text(toastMessage)
                    .foregroundStyle(.green)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .task {
            try? viewModel.load()
        }
        .padding()
    }
}
