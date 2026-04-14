import Foundation
import PersistenceKit
import SharedDomain

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var selectedLanguage: AppLanguage = .english
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
        selectedLanguage = AppLanguage(localeCode: loaded.locale)
        serverURL = loaded.turnServer.url
        serverUsername = loaded.turnServer.username
        serverCredential = loaded.turnServer.credential
    }

    public func save() throws {
        guard serverURL.isEmpty || serverURL.hasPrefix("turn:") else {
            errorMessage = selectedLanguage == .english
            ? "TURN server URL must start with turn:"
            : "TURN 服务器地址必须以 turn: 开头"
            return
        }

        let updated = SettingsMapper.withUpdatedPreferences(
            from: settings,
            locale: selectedLanguage.localeCode,
            url: serverURL,
            username: serverUsername,
            credential: serverCredential
        )

        try settingsStore.save(updated)
        settings = updated
        toastMessage = selectedLanguage == .english ? "Saved" : "已保存"
        errorMessage = nil
    }

    public func reset() throws {
        let resetSettings = try settingsStore.reset()
        settings = resetSettings
        selectedLanguage = AppLanguage(localeCode: resetSettings.locale)
        serverURL = resetSettings.turnServer.url
        serverUsername = resetSettings.turnServer.username
        serverCredential = resetSettings.turnServer.credential
        toastMessage = selectedLanguage == .english ? "Reset" : "已重置"
        errorMessage = nil
    }

    public static func preview() async throws -> SettingsViewModel {
        let store = InMemorySettingsStore()
        let viewModel = SettingsViewModel(settingsStore: store)
        try viewModel.load()
        return viewModel
    }
}
