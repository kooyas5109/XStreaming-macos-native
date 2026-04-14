import Foundation
import NetworkingKit

enum AuthEndpoints {
    static func deviceCode(clientID: String, scope: String) -> BasicEndpoint {
        let body = "client_id=\(clientID)&scope=\(scope)"
        return BasicEndpoint(
            path: "/consumers/oauth2/v2.0/devicecode",
            method: .post,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: Data(body.utf8)
        )
    }

    static func deviceCodeToken(clientID: String, deviceCode: String) -> BasicEndpoint {
        let body = "grant_type=urn:ietf:params:oauth:grant-type:device_code&client_id=\(clientID)&device_code=\(deviceCode)"
        return BasicEndpoint(
            path: "/consumers/oauth2/v2.0/token",
            method: .post,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: Data(body.utf8)
        )
    }

    static func refreshToken(clientID: String, refreshToken: String) -> BasicEndpoint {
        let body = "client_id=\(clientID)&grant_type=refresh_token&refresh_token=\(refreshToken)&scope=xboxlive.signin%20openid%20profile%20offline_access"
        return BasicEndpoint(
            path: "/consumers/oauth2/v2.0/token",
            method: .post,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: Data(body.utf8)
        )
    }

    static func userAuthenticate(accessToken: String) throws -> BasicEndpoint {
        let body = try JSONEncoder().encode(XboxUserAuthenticateRequest(accessToken: accessToken))
        return BasicEndpoint(
            path: "/user/authenticate",
            method: .post,
            headers: xboxJSONHeaders(),
            body: body
        )
    }

    static func xstsAuthorize(userToken: String, relyingParty: String) throws -> BasicEndpoint {
        let body = try JSONEncoder().encode(XSTSAuthorizeRequest(userToken: userToken, relyingParty: relyingParty))
        return BasicEndpoint(
            path: "/xsts/authorize",
            method: .post,
            headers: xboxJSONHeaders(),
            body: body
        )
    }

    static func streamingToken(userToken: String, offeringID: String) throws -> BasicEndpoint {
        let body = try JSONEncoder().encode(StreamingTokenRequest(token: userToken, offeringID: offeringID))
        return BasicEndpoint(
            path: "/v2/login/user",
            method: .post,
            headers: [
                "Content-Type": "application/json",
                "Cache-Control": "no-store, must-revalidate, no-cache",
                "x-gssv-client": "XboxComBrowser"
            ],
            body: body
        )
    }

    private static func xboxJSONHeaders() -> [String: String] {
        [
            "x-xbl-contract-version": "1",
            "Cache-Control": "no-cache",
            "Content-Type": "application/json",
            "Origin": "https://www.xbox.com",
            "Referer": "https://www.xbox.com/"
        ]
    }
}

struct DeviceCodeResponse: Decodable, Equatable, Sendable {
    let userCode: String
    let deviceCode: String
    let verificationURI: String
    let expiresIn: Int
    let interval: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case userCode = "user_code"
        case deviceCode = "device_code"
        case verificationURI = "verification_uri"
        case expiresIn = "expires_in"
        case interval
        case message
    }
}

struct OAuthTokenResponse: Decodable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct XSTSAuthorizeResponse: Decodable, Equatable, Sendable {
    struct DisplayClaims: Decodable, Equatable, Sendable {
        struct XUIClaim: Decodable, Equatable, Sendable {
            let uhs: String
        }

        let xui: [XUIClaim]
    }

    let token: String
    let displayClaims: DisplayClaims

    enum CodingKeys: String, CodingKey {
        case token = "Token"
        case displayClaims = "DisplayClaims"
    }
}

struct StreamingTokenResponse: Decodable, Equatable, Sendable {
    let token: String

    enum CodingKeys: String, CodingKey {
        case token = "token"
    }
}

private struct XboxUserAuthenticateRequest: Encodable {
    struct Properties: Encodable {
        let authMethod = "RPS"
        let siteName = "user.auth.xboxlive.com"
        let rpsTicket: String

        enum CodingKeys: String, CodingKey {
            case authMethod = "AuthMethod"
            case siteName = "SiteName"
            case rpsTicket = "RpsTicket"
        }
    }

    let properties: Properties
    let relyingParty = "http://auth.xboxlive.com"
    let tokenType = "JWT"

    init(accessToken: String) {
        self.properties = Properties(rpsTicket: "d=\(accessToken)")
    }

    enum CodingKeys: String, CodingKey {
        case properties = "Properties"
        case relyingParty = "RelyingParty"
        case tokenType = "TokenType"
    }
}

private struct XSTSAuthorizeRequest: Encodable {
    struct Properties: Encodable {
        let sandboxID = "RETAIL"
        let userTokens: [String]

        enum CodingKeys: String, CodingKey {
            case sandboxID = "SandboxId"
            case userTokens = "UserTokens"
        }
    }

    let properties: Properties
    let relyingParty: String
    let tokenType = "JWT"

    init(userToken: String, relyingParty: String) {
        self.properties = Properties(userTokens: [userToken])
        self.relyingParty = relyingParty
    }

    enum CodingKeys: String, CodingKey {
        case properties = "Properties"
        case relyingParty = "RelyingParty"
        case tokenType = "TokenType"
    }
}

private struct StreamingTokenRequest: Encodable {
    let token: String
    let offeringID: String

    enum CodingKeys: String, CodingKey {
        case token
        case offeringID = "offeringId"
    }
}
