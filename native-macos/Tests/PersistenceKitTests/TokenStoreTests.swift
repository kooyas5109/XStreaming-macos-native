import Foundation
import Testing
@testable import PersistenceKit

@Test
func inMemoryTokenStoreRoundTripsTokens() throws {
    let store = InMemoryTokenStore()
    let tokens = StoredTokens(
        authToken: "auth-token",
        refreshToken: "refresh-token",
        webToken: "web-token",
        userHash: "user-hash",
        xHomeStreamingToken: "xhome-token",
        xHomeBaseURI: "https://xhome.example.com",
        xCloudStreamingToken: "xcloud-token",
        xCloudBaseURI: "https://xcloud.example.com"
    )

    try store.save(tokens)
    #expect(try store.load() == tokens)
}

@Test
func inMemoryTokenStoreClearsTokens() throws {
    let store = InMemoryTokenStore(initialValue: StoredTokens(authToken: "auth"))
    try store.clear()
    #expect(try store.load() == nil)
}
