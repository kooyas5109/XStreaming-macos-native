import Foundation
import NetworkingKit
import PersistenceKit
import SharedDomain

public protocol XboxAuthProviding: Sendable {
    func requestDeviceCode() async throws -> DeviceCodeChallenge
    func completeDeviceCode(challenge: DeviceCodeChallenge) async throws -> AuthSignInResult
}

public struct PreviewXboxAuthProvider: XboxAuthProviding {
    public init() {}

    public func requestDeviceCode() async throws -> DeviceCodeChallenge {
        DeviceCodeChallenge(
            userCode: "ABCD-EFGH",
            deviceCode: "preview-device-code",
            verificationURL: "https://microsoft.com/devicelogin",
            message: "Enter the code at microsoft.com/devicelogin to continue sign-in.",
            expiresInSeconds: 900
        )
    }

    public func completeDeviceCode(challenge: DeviceCodeChallenge) async throws -> AuthSignInResult {
        let profile = UserProfile(
            gamertag: "Native Preview User",
            gamerpicURL: nil,
            gamerscore: "4200",
            appLevel: 2
        )
        let state = AuthState(
            isSignedIn: true,
            isAuthenticating: false,
            userProfile: profile,
            statusMessage: "Signed in through the native device code flow."
        )
        let tokens = StoredTokens(
            authToken: "native-auth-token-\(challenge.userCode)",
            refreshToken: "native-refresh-token",
            webToken: "native-web-token",
            xHomeStreamingToken: "native-xhome-token",
            xCloudStreamingToken: "native-xcloud-token"
        )
        return AuthSignInResult(authState: state, tokens: tokens)
    }
}

public struct LiveXboxAuthProvider: XboxAuthProviding {
    private let httpClient: HTTPClient
    private let clientID: String
    private let deviceCodeBaseURL: URL
    private let xboxUserAuthBaseURL: URL
    private let xstsBaseURL: URL

    public init(
        httpClient: HTTPClient = HTTPClient(),
        clientID: String = "1f907974-e22b-4810-a9de-d9647380c97e",
        deviceCodeBaseURL: URL = URL(string: "https://login.microsoftonline.com")!,
        xboxUserAuthBaseURL: URL = URL(string: "https://user.auth.xboxlive.com")!,
        xstsBaseURL: URL = URL(string: "https://xsts.auth.xboxlive.com")!
    ) {
        self.httpClient = httpClient
        self.clientID = clientID
        self.deviceCodeBaseURL = deviceCodeBaseURL
        self.xboxUserAuthBaseURL = xboxUserAuthBaseURL
        self.xstsBaseURL = xstsBaseURL
    }

    public func requestDeviceCode() async throws -> DeviceCodeChallenge {
        let endpoint = AuthEndpoints.deviceCode(
            clientID: clientID,
            scope: "xboxlive.signin%20openid%20profile%20offline_access"
        )
        let request = try RequestBuilder.make(baseURL: deviceCodeBaseURL, endpoint: endpoint)
        let response = try await httpClient.send(request)
        let payload = try httpClient.decode(DeviceCodeResponse.self, from: response)
        return DeviceCodeChallenge(
            userCode: payload.userCode,
            deviceCode: payload.deviceCode,
            verificationURL: payload.verificationURI,
            message: payload.message,
            expiresInSeconds: payload.expiresIn
        )
    }

    public func completeDeviceCode(challenge: DeviceCodeChallenge) async throws -> AuthSignInResult {
        let tokenResponse = try await fetchOAuthTokens(deviceCode: challenge.deviceCode)
        let userAuth = try await authenticateXbox(accessToken: tokenResponse.accessToken)
        let webToken = try await authorizeXSTS(
            userToken: userAuth.token,
            relyingParty: "http://xboxlive.com"
        )
        let gssvToken = try await authorizeXSTS(
            userToken: userAuth.token,
            relyingParty: "http://gssv.xboxlive.com/"
        )
        let xHomeToken = try await fetchStreamingToken(
            userToken: gssvToken.token,
            offeringID: "xhome"
        )
        let xCloudToken = try? await fetchStreamingToken(
            userToken: gssvToken.token,
            offeringID: "xgpuweb"
        )

        let state = AuthState(
            isSignedIn: true,
            isAuthenticating: false,
            userProfile: UserProfile(
                gamertag: "Xbox User",
                gamerpicURL: nil,
                gamerscore: "",
                appLevel: xCloudToken == nil ? 1 : 2
            ),
            statusMessage: "Signed in through the live MSAL-first device code flow."
        )
        let tokens = StoredTokens(
            authToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            webToken: webToken.token,
            xHomeStreamingToken: xHomeToken.token,
            xCloudStreamingToken: xCloudToken?.token
        )
        return AuthSignInResult(authState: state, tokens: tokens)
    }

    private func fetchOAuthTokens(deviceCode: String) async throws -> OAuthTokenResponse {
        let endpoint = AuthEndpoints.deviceCodeToken(clientID: clientID, deviceCode: deviceCode)
        let request = try RequestBuilder.make(baseURL: deviceCodeBaseURL, endpoint: endpoint)
        let response = try await httpClient.send(request)
        return try httpClient.decode(OAuthTokenResponse.self, from: response)
    }

    private func authenticateXbox(accessToken: String) async throws -> XSTSAuthorizeResponse {
        let endpoint = try AuthEndpoints.userAuthenticate(accessToken: accessToken)
        let request = try RequestBuilder.make(baseURL: xboxUserAuthBaseURL, endpoint: endpoint)
        let response = try await httpClient.send(request)
        return try httpClient.decode(XSTSAuthorizeResponse.self, from: response)
    }

    private func authorizeXSTS(userToken: String, relyingParty: String) async throws -> XSTSAuthorizeResponse {
        let endpoint = try AuthEndpoints.xstsAuthorize(userToken: userToken, relyingParty: relyingParty)
        let request = try RequestBuilder.make(baseURL: xstsBaseURL, endpoint: endpoint)
        let response = try await httpClient.send(request)
        return try httpClient.decode(XSTSAuthorizeResponse.self, from: response)
    }

    private func fetchStreamingToken(userToken: String, offeringID: String) async throws -> StreamingTokenResponse {
        let endpoint = try AuthEndpoints.streamingToken(userToken: userToken, offeringID: offeringID)
        let baseURL = URL(string: "https://\(offeringID).gssv-play-prod.xboxlive.com")!
        let request = try RequestBuilder.make(baseURL: baseURL, endpoint: endpoint)
        let response = try await httpClient.send(request)
        return try httpClient.decode(StreamingTokenResponse.self, from: response)
    }
}
