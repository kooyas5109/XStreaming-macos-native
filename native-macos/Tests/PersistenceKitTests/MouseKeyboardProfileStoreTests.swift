import Foundation
import SharedDomain
import Testing
@testable import PersistenceKit

@Test
func mouseKeyboardProfileStoreReturnsBuiltInDefaultsOnFirstLaunch() throws {
    let store = InMemoryMouseKeyboardProfileStore()

    let profiles = try store.load()

    #expect(profiles.enabled)
    #expect(profiles.selectedProfileID == MouseKeyboardProfiles.standardProfile.id)
    #expect(profiles.profiles.map(\.id) == [
        MouseKeyboardProfiles.standardProfile.id,
        MouseKeyboardProfiles.shooterProfile.id
    ])
}

@Test
func userDefaultsMouseKeyboardProfileStorePersistsBuiltInMouseSettings() throws {
    let suiteName = "MouseKeyboardProfileStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let store = UserDefaultsMouseKeyboardProfileStore(userDefaults: defaults, key: "profiles")
    var profiles = MouseKeyboardProfiles.defaults
    profiles.enabled = false
    profiles.profiles = profiles.profiles.map { profile in
        guard profile.id == MouseKeyboardProfiles.standardProfile.id else {
            return profile
        }
        var updated = profile
        updated.mouse = MouseKeyboardMouseSettings(
            mapTo: .leftStick,
            sensitivityX: 175,
            sensitivityY: 125,
            deadzoneCounterweight: 35
        )
        return updated
    }

    try store.save(profiles)
    let loaded = try store.load()

    #expect(loaded.enabled == false)
    #expect(loaded.selectedProfile.mouse.mapTo == .leftStick)
    #expect(loaded.selectedProfile.mouse.sensitivityX == 175)
    #expect(loaded.selectedProfile.mouse.sensitivityY == 125)
    #expect(loaded.selectedProfile.mouse.deadzoneCounterweight == 35)
}
