import Foundation
import SharedDomain

public protocol MouseKeyboardProfileStoreProtocol: Sendable {
    func load() throws -> MouseKeyboardProfiles
    func save(_ profiles: MouseKeyboardProfiles) throws
    func reset() throws -> MouseKeyboardProfiles
}

public final class UserDefaultsMouseKeyboardProfileStore: MouseKeyboardProfileStoreProtocol, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(userDefaults: UserDefaults = .standard, key: String = "input.mouseKeyboardProfiles") {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func load() throws -> MouseKeyboardProfiles {
        guard let data = userDefaults.data(forKey: key) else {
            return .defaults
        }

        do {
            return mergedWithBuiltIns(try decoder.decode(MouseKeyboardProfiles.self, from: data))
        } catch {
            return .defaults
        }
    }

    public func save(_ profiles: MouseKeyboardProfiles) throws {
        let data = try encoder.encode(mergedWithBuiltIns(profiles))
        userDefaults.set(data, forKey: key)
    }

    public func reset() throws -> MouseKeyboardProfiles {
        let defaults = MouseKeyboardProfiles.defaults
        try save(defaults)
        return defaults
    }

    private func mergedWithBuiltIns(_ profiles: MouseKeyboardProfiles) -> MouseKeyboardProfiles {
        let profilesByID = Dictionary(uniqueKeysWithValues: profiles.profiles.map { ($0.id, $0) })
        var mergedProfiles = profiles.profiles.filter {
            $0.id != MouseKeyboardProfiles.standardProfile.id && $0.id != MouseKeyboardProfiles.shooterProfile.id
        }
        mergedProfiles.insert(
            builtInProfile(from: profilesByID[MouseKeyboardProfiles.shooterProfile.id], fallback: MouseKeyboardProfiles.shooterProfile),
            at: 0
        )
        mergedProfiles.insert(
            builtInProfile(from: profilesByID[MouseKeyboardProfiles.standardProfile.id], fallback: MouseKeyboardProfiles.standardProfile),
            at: 0
        )
        let selected = mergedProfiles.contains { $0.id == profiles.selectedProfileID }
        ? profiles.selectedProfileID
        : MouseKeyboardProfiles.standardProfile.id
        return MouseKeyboardProfiles(
            enabled: profiles.enabled,
            selectedProfileID: selected,
            profiles: mergedProfiles
        )
    }

    private func builtInProfile(
        from storedProfile: MouseKeyboardMappingProfile?,
        fallback: MouseKeyboardMappingProfile
    ) -> MouseKeyboardMappingProfile {
        guard let storedProfile else {
            return fallback
        }

        return MouseKeyboardMappingProfile(
            id: fallback.id,
            name: fallback.name,
            bindings: storedProfile.bindings.isEmpty ? fallback.bindings : storedProfile.bindings,
            mouse: storedProfile.mouse,
            isBuiltIn: true
        )
    }
}

public final class InMemoryMouseKeyboardProfileStore: MouseKeyboardProfileStoreProtocol, @unchecked Sendable {
    private var currentProfiles: MouseKeyboardProfiles?

    public init(initialValue: MouseKeyboardProfiles? = nil) {
        self.currentProfiles = initialValue
    }

    public func load() throws -> MouseKeyboardProfiles {
        currentProfiles ?? .defaults
    }

    public func save(_ profiles: MouseKeyboardProfiles) throws {
        currentProfiles = profiles
    }

    public func reset() throws -> MouseKeyboardProfiles {
        currentProfiles = .defaults
        return .defaults
    }
}
