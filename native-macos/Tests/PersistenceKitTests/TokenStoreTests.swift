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

@Test
func storedTokensDecodeLegacyPayloadWithoutBaseURIs() throws {
    let data = Data(
        """
        {
          "authToken": "auth-token",
          "refreshToken": "refresh-token",
          "webToken": "web-token",
          "userHash": "user-hash",
          "xHomeStreamingToken": "xhome-token",
          "xCloudStreamingToken": "xcloud-token"
        }
        """.utf8
    )

    let decoded = try JSONDecoder().decode(StoredTokens.self, from: data)
    #expect(decoded.authToken == "auth-token")
    #expect(decoded.refreshToken == "refresh-token")
    #expect(decoded.webToken == "web-token")
    #expect(decoded.userHash == "user-hash")
    #expect(decoded.xHomeStreamingToken == "xhome-token")
    #expect(decoded.xHomeBaseURI == nil)
    #expect(decoded.xCloudStreamingToken == "xcloud-token")
    #expect(decoded.xCloudBaseURI == nil)
}
