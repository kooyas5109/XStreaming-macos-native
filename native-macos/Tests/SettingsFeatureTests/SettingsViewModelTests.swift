import PersistenceKit
import SharedDomain
import Testing
@testable import SettingsFeature

@MainActor
@Test
func savingTurnServerUpdatesSettingsStore() async throws {
    let store = InMemorySettingsStore()
    let model = SettingsViewModel(settingsStore: store)
    try model.load()

    model.serverURL = "turn:relay.example.com"
    model.serverUsername = "user"
    model.serverCredential = "secret"

    try model.save()

    let persisted = try store.load()
    #expect(persisted.turnServer.url == "turn:relay.example.com")
    #expect(model.toastMessage == "Saved")
}

@MainActor
@Test
func savingInvalidTurnServerShowsValidationError() throws {
    let store = InMemorySettingsStore()
    let model = SettingsViewModel(settingsStore: store)
    try model.load()

    model.serverURL = "https://invalid.example.com"
    try model.save()

    #expect(model.errorMessage == "TURN server URL must start with turn:")
}

@MainActor
@Test
func resetRestoresDefaultSettings() throws {
    let store = InMemorySettingsStore(initialValue: SettingsMapper.withUpdatedTurnServer(
        from: .defaults,
        url: "turn:relay.example.com",
        username: "user",
        credential: "secret"
    ))
    let model = SettingsViewModel(settingsStore: store)
    try model.load()

    try model.reset()

    #expect(model.settings == .defaults)
    #expect(model.serverURL == "")
    #expect(model.toastMessage == "Reset")
}
