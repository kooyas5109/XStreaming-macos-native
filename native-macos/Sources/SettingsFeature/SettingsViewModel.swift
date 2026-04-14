import Foundation
import PersistenceKit
import SharedDomain

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var serverURL: String = ""
    @Published public var serverUsername: String = ""
    @Published public var serverCredential: String = ""
    @Published public private(set) var settings: AppSettings = .defaults
    @Published public private(set) var toastMessage: String?
    @Published public private(set) var errorMessage: String?

    private let settingsStore: SettingsStoreProtocol

    public init(settingsStore: SettingsStoreProtocol) {
        self.settingsStore = settingsStore
    }

    public func load() throws {
        let loaded = try settingsStore.load()
        settings = loaded
        serverURL = loaded.turnServer.url
        serverUsername = loaded.turnServer.username
        serverCredential = loaded.turnServer.credential
    }

    public func save() throws {
        guard serverURL.isEmpty || serverURL.hasPrefix("turn:") else {
            errorMessage = "TURN server URL must start with turn:"
            return
        }

        let updated = SettingsMapper.withUpdatedTurnServer(
            from: settings,
            url: serverURL,
            username: serverUsername,
            credential: serverCredential
        )

        try settingsStore.save(updated)
        settings = updated
        toastMessage = "Saved"
        errorMessage = nil
    }

    public func reset() throws {
        let resetSettings = try settingsStore.reset()
        settings = resetSettings
        serverURL = resetSettings.turnServer.url
        serverUsername = resetSettings.turnServer.username
        serverCredential = resetSettings.turnServer.credential
        toastMessage = "Reset"
        errorMessage = nil
    }

    public static func preview() async throws -> SettingsViewModel {
        let store = InMemorySettingsStore()
        let viewModel = SettingsViewModel(settingsStore: store)
        try viewModel.load()
        return viewModel
    }
}
