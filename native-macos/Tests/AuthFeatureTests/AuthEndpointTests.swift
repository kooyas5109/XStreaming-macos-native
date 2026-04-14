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
