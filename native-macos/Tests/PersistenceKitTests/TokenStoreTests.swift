import Foundation
import Testing
@testable import PersistenceKit

@Test
func inMemoryTokenStoreRoundTripsTokens() throws {
    let store = InMemoryTokenStore()
    let tokens = StoredTokens(
        authToken: "auth-token",
        webToken: "web-token",
        streamingToken: "stream-token"
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
