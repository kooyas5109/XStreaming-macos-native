import SwiftUI

public struct AuthView: View {
    @StateObject private var viewModel: AuthViewModel

    public init(viewModel: AuthViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Authentication")
                .font(.title2.bold())

            Text(viewModel.state.authState.isSignedIn ? "Signed in" : "Signed out")
                .foregroundStyle(viewModel.state.authState.isSignedIn ? .green : .secondary)

            if let gamertag = viewModel.state.authState.userProfile?.gamertag, gamertag.isEmpty == false {
                Text("Gamertag: \(gamertag)")
            }

            if let statusMessage = viewModel.state.authState.statusMessage {
                Text(statusMessage)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = viewModel.state.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
