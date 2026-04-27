import Foundation
import PersistenceKit
import SharedDomain
import SupportKit

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var selectedLanguage: AppLanguage = .simplifiedChinese
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
    @Published public var mouseKeyboardEnabled: Bool = true
    @Published public var selectedMouseKeyboardProfileID: String = MouseKeyboardProfiles.standardProfile.id
    @Published public var mouseKeyboardMouseTarget: MouseKeyboardMouseTarget = .rightStick
    @Published public var mouseKeyboardSensitivityX: Double = 100
    @Published public var mouseKeyboardSensitivityY: Double = 100
    @Published public var mouseKeyboardDeadzoneCounterweight: Double = 20
    @Published public var serverURL: String = ""
    @Published public var serverUsername: String = ""
    @Published public var serverCredential: String = ""
    @Published public private(set) var settings: AppSettings = .defaults
    @Published public private(set) var toastMessage: String?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var mouseKeyboardProfiles: MouseKeyboardProfiles = .defaults

    private let settingsStore: SettingsStoreProtocol
    private let mouseKeyboardProfileStore: MouseKeyboardProfileStoreProtocol

    public init(
        settingsStore: SettingsStoreProtocol,
        mouseKeyboardProfileStore: MouseKeyboardProfileStoreProtocol = UserDefaultsMouseKeyboardProfileStore()
    ) {
        self.settingsStore = settingsStore
        self.mouseKeyboardProfileStore = mouseKeyboardProfileStore
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
        let profiles = try mouseKeyboardProfileStore.load()
        mouseKeyboardProfiles = profiles
        applyMouseKeyboardProfiles(profiles)
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
        try mouseKeyboardProfileStore.save(updatedMouseKeyboardProfiles())
        mouseKeyboardProfiles = try mouseKeyboardProfileStore.load()
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
        let resetProfiles = try mouseKeyboardProfileStore.reset()
        mouseKeyboardProfiles = resetProfiles
        applyMouseKeyboardProfiles(resetProfiles)
        toastMessage = selectedLanguage == .english ? "Reset" : "已重置"
        errorMessage = nil
    }

    public func selectMouseKeyboardProfile(_ profileID: String) {
        let profiles = updatedMouseKeyboardProfiles().selectingProfile(profileID)
        mouseKeyboardProfiles = profiles
        applyMouseKeyboardProfiles(profiles)
    }

    public var selectedMouseKeyboardProfile: MouseKeyboardMappingProfile {
        mouseKeyboardProfiles.profile(withID: selectedMouseKeyboardProfileID) ?? MouseKeyboardProfiles.standardProfile
    }

    public func binding(for control: MouseKeyboardGamepadControl, slot: Int) -> String? {
        mouseKeyboardProfiles.binding(for: control, slot: slot, in: selectedMouseKeyboardProfileID)
    }

    public func setBinding(_ code: String?, for control: MouseKeyboardGamepadControl, slot: Int) {
        mutateSelectedProfile { profile in
            let sanitizedCode = code?.trimmingCharacters(in: .whitespacesAndNewlines)
            var updatedBindings = profile.bindings

            if let sanitizedCode, sanitizedCode.isEmpty == false {
                for existingControl in MouseKeyboardProfiles.controlOrder {
                    var values = updatedBindings[existingControl] ?? []
                    values.removeAll { $0 == sanitizedCode }
                    while values.last?.isEmpty == true { values.removeLast() }
                    if values.isEmpty {
                        updatedBindings.removeValue(forKey: existingControl)
                    } else {
                        updatedBindings[existingControl] = values
                    }
                }
            }

            var values = updatedBindings[control] ?? []
            while values.count <= slot {
                values.append("")
            }

            if let sanitizedCode, sanitizedCode.isEmpty == false {
                values[slot] = sanitizedCode
            } else if slot < values.count {
                values[slot] = ""
            }

            while values.last?.isEmpty == true { values.removeLast() }
            if values.isEmpty {
                updatedBindings.removeValue(forKey: control)
            } else {
                updatedBindings[control] = values
            }

            profile.bindings = updatedBindings
        }
    }

    public func updateSelectedProfileName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            return
        }
        mutateSelectedProfile { profile in
            profile.name = trimmedName
        }
    }

    public func createProfile() {
        let existingNames = Set(mouseKeyboardProfiles.profiles.map(\.name))
        var suffix = 1
        var name = selectedLanguage == .english ? "Custom \(suffix)" : "自定义 \(suffix)"
        while existingNames.contains(name) {
            suffix += 1
            name = selectedLanguage == .english ? "Custom \(suffix)" : "自定义 \(suffix)"
        }

        let profile = MouseKeyboardProfiles.blankCustomProfile(name: name)
        let profiles = updatedMouseKeyboardProfiles().upserting(profile)
        mouseKeyboardProfiles = profiles
        applyMouseKeyboardProfiles(profiles)
    }

    public func duplicateSelectedProfile() {
        var duplicate = selectedMouseKeyboardProfile
        duplicate.id = UUID().uuidString.lowercased()
        duplicate.isBuiltIn = false
        duplicate.name = selectedLanguage == .english
        ? "\(selectedMouseKeyboardProfile.name) Copy"
        : "\(selectedMouseKeyboardProfile.name) 副本"

        let profiles = updatedMouseKeyboardProfiles().upserting(duplicate)
        mouseKeyboardProfiles = profiles
        applyMouseKeyboardProfiles(profiles)
    }

    public func deleteSelectedProfile() {
        guard selectedMouseKeyboardProfile.isBuiltIn == false else {
            return
        }
        let profiles = updatedMouseKeyboardProfiles().deletingProfile(selectedMouseKeyboardProfileID)
        mouseKeyboardProfiles = profiles
        applyMouseKeyboardProfiles(profiles)
    }

    public func importMouseKeyboardProfile(from url: URL) throws {
        switch try MouseKeyboardProfileFileCodec.readImportPayload(from: url) {
        case .profiles(let profiles):
            mouseKeyboardProfiles = profiles
            applyMouseKeyboardProfiles(profiles)
        case .profile(let profile):
            let profiles = updatedMouseKeyboardProfiles().upserting(profile)
            mouseKeyboardProfiles = profiles
            applyMouseKeyboardProfiles(profiles)
        }
    }

    public func exportSelectedProfile(to url: URL) throws {
        try MouseKeyboardProfileFileCodec.writeProfile(selectedMouseKeyboardProfile, to: url)
    }

    public static func preview() async throws -> SettingsViewModel {
        let store = InMemorySettingsStore()
        let viewModel = SettingsViewModel(
            settingsStore: store,
            mouseKeyboardProfileStore: InMemoryMouseKeyboardProfileStore()
        )
        try viewModel.load()
        return viewModel
    }

    private func applyMouseKeyboardProfiles(_ profiles: MouseKeyboardProfiles) {
        mouseKeyboardEnabled = profiles.enabled
        selectedMouseKeyboardProfileID = profiles.selectedProfileID
        let mouse = profiles.selectedProfile.mouse
        mouseKeyboardMouseTarget = mouse.mapTo
        mouseKeyboardSensitivityX = mouse.sensitivityX
        mouseKeyboardSensitivityY = mouse.sensitivityY
        mouseKeyboardDeadzoneCounterweight = mouse.deadzoneCounterweight
    }

    private func updatedMouseKeyboardProfiles() -> MouseKeyboardProfiles {
        var profiles = mouseKeyboardProfiles
        profiles.enabled = mouseKeyboardEnabled
        profiles.selectedProfileID = selectedMouseKeyboardProfileID
        profiles.profiles = profiles.profiles.map { profile in
            guard profile.id == selectedMouseKeyboardProfileID else {
                return profile
            }
            var updated = profile
            updated.mouse = MouseKeyboardMouseSettings(
                mapTo: mouseKeyboardMouseTarget,
                sensitivityX: mouseKeyboardSensitivityX,
                sensitivityY: mouseKeyboardSensitivityY,
                deadzoneCounterweight: mouseKeyboardDeadzoneCounterweight
            )
            return updated
        }
        return profiles
    }

    private func mutateSelectedProfile(_ update: (inout MouseKeyboardMappingProfile) -> Void) {
        var profiles = updatedMouseKeyboardProfiles()
        guard let index = profiles.profiles.firstIndex(where: { $0.id == profiles.selectedProfileID }) else {
            return
        }

        var updatedProfile = profiles.profiles[index]
        update(&updatedProfile)
        profiles.profiles[index] = updatedProfile
        mouseKeyboardProfiles = profiles
        applyMouseKeyboardProfiles(profiles)
    }
}
