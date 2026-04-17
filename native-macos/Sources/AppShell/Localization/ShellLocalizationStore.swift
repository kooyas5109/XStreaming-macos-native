import Combine
import PersistenceKit
import SharedDomain

@MainActor
public final class ShellLocalizationStore: ObservableObject {
    @Published public private(set) var language: AppLanguage = .simplifiedChinese

    private let settingsStore: SettingsStoreProtocol

    public init(settingsStore: SettingsStoreProtocol) {
        self.settingsStore = settingsStore
    }

    public func load() {
        let settings = (try? settingsStore.load()) ?? .defaults
        apply(settings: settings)
    }

    public func apply(settings: AppSettings) {
        language = AppLanguage(localeCode: settings.locale)
    }
}
