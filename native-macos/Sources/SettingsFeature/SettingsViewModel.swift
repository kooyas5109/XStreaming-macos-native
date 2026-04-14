import Foundation
import PersistenceKit
import SharedDomain

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var selectedLanguage: AppLanguage = .english
    @Published public var preferredGameLanguage: String = "en-US"
    @Published public var launchesFullscreen: Bool = false
    @Published public var performanceStyleEnabled: Bool = false
    @Published public var resolution: Int = 720
    @Published public var videoFormat: String = ""
    @Published public var codec: String = ""
    @Published public var hostBitrate: Double = 20
    @Published public var cloudBitrate: Double = 20
    @Published public var audioBitrate: Double = 20
    @Published public var vibrationEnabled: Bool = true
    @Published public var nativeMouseKeyboardEnabled: Bool = false
    @Published public var mouseSensitivity: Double = 0.5
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
        preferredGameLanguage = loaded.preferredGameLanguage
        launchesFullscreen = loaded.fullscreen
        performanceStyleEnabled = loaded.performanceStyle
        resolution = loaded.resolution
        videoFormat = loaded.videoFormat
        codec = loaded.codec
        hostBitrate = Double(loaded.xhomeBitrate)
        cloudBitrate = Double(loaded.xcloudBitrate)
        audioBitrate = Double(loaded.audioBitrate)
        vibrationEnabled = loaded.vibration
        nativeMouseKeyboardEnabled = loaded.enableNativeMouseKeyboard
        mouseSensitivity = loaded.mouseSensitive
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

        let settingsWithPresentation = SettingsMapper.withUpdatedPreferences(
            from: settings,
            locale: selectedLanguage.localeCode,
            preferredGameLanguage: preferredGameLanguage,
            fullscreen: launchesFullscreen,
            performanceStyle: performanceStyleEnabled,
            url: serverURL,
            username: serverUsername,
            credential: serverCredential
        )

        let updated = SettingsMapper.withUpdatedStreamingPreferences(
            from: settingsWithPresentation,
            resolution: resolution,
            videoFormat: videoFormat,
            codec: codec,
            xhomeBitrate: Int(hostBitrate.rounded()),
            xcloudBitrate: Int(cloudBitrate.rounded()),
            audioBitrate: Int(audioBitrate.rounded()),
            vibration: vibrationEnabled,
            enableNativeMouseKeyboard: nativeMouseKeyboardEnabled,
            mouseSensitive: mouseSensitivity
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
        preferredGameLanguage = resetSettings.preferredGameLanguage
        launchesFullscreen = resetSettings.fullscreen
        performanceStyleEnabled = resetSettings.performanceStyle
        resolution = resetSettings.resolution
        videoFormat = resetSettings.videoFormat
        codec = resetSettings.codec
        hostBitrate = Double(resetSettings.xhomeBitrate)
        cloudBitrate = Double(resetSettings.xcloudBitrate)
        audioBitrate = Double(resetSettings.audioBitrate)
        vibrationEnabled = resetSettings.vibration
        nativeMouseKeyboardEnabled = resetSettings.enableNativeMouseKeyboard
        mouseSensitivity = resetSettings.mouseSensitive
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
