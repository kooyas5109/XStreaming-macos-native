import Foundation
import Testing
@testable import AuthFeature
@testable import NetworkingKit

@Test
func deviceCodeEndpointMatchesMicrosoftFormRequest() throws {
    let endpoint = AuthEndpoints.deviceCode(
        clientID: "client-id",
        scope: "xboxlive.signin%20openid"
    )
    let request = try RequestBuilder.make(
        baseURL: URL(string: "https://login.microsoftonline.com")!,
        endpoint: endpoint
    )

    #expect(request.url?.absoluteString == "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
    #expect(String(data: request.httpBody ?? Data(), encoding: .utf8) == "client_id=client-id&scope=xboxlive.signin%20openid")
}

@Test
func streamingTokenEndpointMatchesLegacyXboxHeaders() throws {
    let endpoint = try AuthEndpoints.streamingToken(
        userToken: "gssv-token",
        offeringID: "xhome"
    )
    let request = try RequestBuilder.make(
        baseURL: URL(string: "https://xhome.gssv-play-prod.xboxlive.com")!,
        endpoint: endpoint
    )

    #expect(request.url?.absoluteString == "https://xhome.gssv-play-prod.xboxlive.com/v2/login/user")
    #expect(request.value(forHTTPHeaderField: "x-gssv-client") == "XboxComBrowser")
    #expect(request.httpMethod == "POST")
}

@Test
func streamingTokenResponseDecodesLegacyGsTokenField() throws {
    let data = Data(
        """
        {
          "gsToken": "stream-token",
          "tokenType": "JWT",
          "durationInSeconds": 3600,
          "offeringSettings": {
            "regions": [
              {
                "name": "fallback",
                "baseUri": "https://fallback.example.com",
                "isDefault": false
              },
              {
                "name": "default",
                "baseUri": "https://default.example.com",
                "isDefault": true
              }
            ]
          }
        }
        """.utf8
    )

    let decoded = try JSONDecoder().decode(StreamingTokenResponse.self, from: data)
    #expect(decoded.token == "stream-token")
    #expect(decoded.defaultBaseURI == "https://default.example.com")
}

@Test
func profileEndpointMatchesLegacyXboxHeaders() throws {
    let endpoint = AuthEndpoints.userProfile(userToken: "web-token", userHash: "12345")
    let request = try RequestBuilder.make(
        baseURL: URL(string: "https://profile.xboxlive.com")!,
        endpoint: endpoint
    )

    #expect(request.url?.absoluteString == "https://profile.xboxlive.com/users/me/profile/settings?settings=GameDisplayName,GameDisplayPicRaw,Gamerscore,Gamertag")
    #expect(request.httpMethod == "GET")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "XBL3.0 x=12345;web-token")
    #expect(request.value(forHTTPHeaderField: "x-xbl-contract-version") == "2")
}

@Test
func profileResponseDecodesLegacySettingsPayload() throws {
    let data = Data(
        """
        {
          "profileUsers": [
            {
              "settings": [
                { "id": "Gamertag", "value": "Kooyas" },
                { "id": "GameDisplayPicRaw", "value": "https://example.com/pic.png" },
                { "id": "Gamerscore", "value": "12345" }
              ]
            }
          ]
        }
        """.utf8
    )

    let decoded = try JSONDecoder().decode(ProfileSettingsResponse.self, from: data)
    let profile = decoded.asUserProfile()
    #expect(profile.gamertag == "Kooyas")
    #expect(profile.gamerpicURL?.absoluteString == "https://example.com/pic.png")
    #expect(profile.gamerscore == "12345")
}

@Test
func profileResponseToleratesMissingAndNullSettings() throws {
    let data = Data(
        """
        {
          "profileUsers": [
            {
              "settings": [
                { "id": "GameDisplayName", "value": "Display User" },
                { "id": "GameDisplayPicRaw", "value": null },
                { "id": "Gamerscore", "value": "987" }
              ]
            },
            {}
          ]
        }
        """.utf8
    )

    let decoded = try JSONDecoder().decode(ProfileSettingsResponse.self, from: data)
    let profile = decoded.asUserProfile()
    #expect(profile.gamertag == "Display User")
    #expect(profile.gamerpicURL == nil)
    #expect(profile.gamerscore == "987")
}
