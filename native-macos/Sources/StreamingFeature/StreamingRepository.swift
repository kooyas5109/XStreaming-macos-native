import Foundation
import NetworkingKit
import PersistenceKit
import SharedDomain

public protocol StreamingRepository: Sendable {
    func createSession(kind: StreamingKind, targetID: String) async throws -> StreamingSession
    func refreshSession(sessionID: String) async throws -> StreamingSession
    func sendKeepAlive(sessionID: String) async throws
    func stopSession(sessionID: String) async throws
}

public final class PreviewStreamingRepository: @unchecked Sendable, StreamingRepository {
    private let createdSession: StreamingSession
    private let refreshedSessions: [StreamingSession]
    private var refreshIndex = 0

    public init(
        createdSession: StreamingSession,
        refreshedSessions: [StreamingSession]
    ) {
        self.createdSession = createdSession
        self.refreshedSessions = refreshedSessions
    }

    public convenience init() {
        self.init(
            createdSession: StreamingFixtures.pendingSession,
            refreshedSessions: StreamingFixtures.readySequence
        )
    }

    public func createSession(kind: StreamingKind, targetID: String) async throws -> StreamingSession {
        StreamingSession(
            id: createdSession.id,
            targetID: targetID,
            sessionPath: createdSession.sessionPath,
            kind: kind,
            state: createdSession.state,
            waitingTimeMinutes: createdSession.waitingTimeMinutes,
            errorDetails: createdSession.errorDetails
        )
    }

    public func refreshSession(sessionID: String) async throws -> StreamingSession {
        guard refreshIndex < refreshedSessions.count else {
            return refreshedSessions.last ?? createdSession
        }

        let session = refreshedSessions[refreshIndex]
        refreshIndex += 1
        return session
    }

    public func sendKeepAlive(sessionID: String) async throws {}

    public func stopSession(sessionID: String) async throws {}
}

public enum LiveStreamingRepositoryError: Error, Equatable {
    case missingToken(StreamingKind)
    case invalidBaseURI(String)
}

public final class LiveStreamingRepository: @unchecked Sendable, StreamingRepository {
    private let httpClient: HTTPClient
    private let tokenStore: TokenStoreProtocol
    private let defaultHomeBaseURI: String
    private let defaultCloudBaseURI: String

    public init(
        httpClient: HTTPClient = HTTPClient(),
        tokenStore: TokenStoreProtocol,
        defaultHomeBaseURI: String = "https://xhome.gssv-play-prod.xboxlive.com",
        defaultCloudBaseURI: String = "https://xgpuweb.gssv-play-prod.xboxlive.com"
    ) {
        self.httpClient = httpClient
        self.tokenStore = tokenStore
        self.defaultHomeBaseURI = defaultHomeBaseURI
        self.defaultCloudBaseURI = defaultCloudBaseURI
    }

    public func createSession(kind: StreamingKind, targetID: String) async throws -> StreamingSession {
        let context = try loadContext(kind: kind)
        let endpoint = try StreamingEndpoints.play(kind: kind, targetID: targetID)
        let request = try RequestBuilder.make(
            baseURL: context.baseURL,
            endpoint: endpoint,
            token: context.streamingToken
        )
        let response = try await httpClient.send(request)
        let payload = try httpClient.decode(StreamingPlayResponse.self, from: response)
        let session = payload.asStreamingSession(kind: kind, targetID: targetID)
        sessionContexts[session.id] = StreamingSessionContext(
            kind: kind,
            targetID: targetID,
            sessionPath: session.sessionPath,
            streamingToken: context.streamingToken,
            baseURL: context.baseURL
        )
        return session
    }

    public func refreshSession(sessionID: String) async throws -> StreamingSession {
        guard let context = sessionContexts[sessionID] else {
            return StreamingSession(
                id: sessionID,
                targetID: "",
                sessionPath: "/v5/sessions/home/\(sessionID)",
                kind: .home,
                state: .failed,
                errorDetails: StreamingErrorDetails(code: "session_not_found", message: "Streaming session context was not found.")
            )
        }

        let request = try RequestBuilder.make(
            baseURL: context.baseURL,
            endpoint: StreamingEndpoints.state(kind: context.kind, sessionID: sessionID),
            token: context.streamingToken
        )
        let response = try await httpClient.send(request)
        let payload = try httpClient.decode(StreamingStateResponse.self, from: response)
        return payload.asStreamingSession(
            id: sessionID,
            targetID: context.targetID,
            sessionPath: context.sessionPath,
            kind: context.kind
        )
    }

    public func sendKeepAlive(sessionID: String) async throws {
        guard let context = sessionContexts[sessionID] else { return }
        let request = try RequestBuilder.make(
            baseURL: context.baseURL,
            endpoint: StreamingEndpoints.keepAlive(kind: context.kind, sessionID: sessionID),
            token: context.streamingToken
        )
        _ = try await httpClient.send(request)
    }

    public func stopSession(sessionID: String) async throws {
        guard let context = sessionContexts.removeValue(forKey: sessionID) else { return }
        let request = try RequestBuilder.make(
            baseURL: context.baseURL,
            endpoint: StreamingEndpoints.stop(kind: context.kind, sessionID: sessionID),
            token: context.streamingToken
        )
        _ = try await httpClient.send(request)
    }

    private var sessionContexts: [String: StreamingSessionContext] = [:]

    private func loadContext(kind: StreamingKind) throws -> StreamingAuthContext {
        let tokens = try tokenStore.load()
        let streamingToken: String?
        let baseURI: String?

        switch kind {
        case .home:
            streamingToken = tokens?.xHomeStreamingToken
            baseURI = tokens?.xHomeBaseURI ?? defaultHomeBaseURI
        case .cloud:
            streamingToken = tokens?.xCloudStreamingToken
            baseURI = tokens?.xCloudBaseURI ?? defaultCloudBaseURI
        }

        guard let streamingToken, streamingToken.isEmpty == false else {
            throw LiveStreamingRepositoryError.missingToken(kind)
        }
        guard let baseURI, let baseURL = URL(string: baseURI) else {
            throw LiveStreamingRepositoryError.invalidBaseURI(baseURI ?? "")
        }

        return StreamingAuthContext(streamingToken: streamingToken, baseURL: baseURL)
    }
}

private struct StreamingAuthContext {
    let streamingToken: String
    let baseURL: URL
}

private struct StreamingSessionContext {
    let kind: StreamingKind
    let targetID: String
    let sessionPath: String
    let streamingToken: String
    let baseURL: URL
}

private enum StreamingEndpoints {
    static func play(kind: StreamingKind, targetID: String) throws -> BasicEndpoint {
        let body = try JSONEncoder().encode(StreamingPlayRequest(kind: kind, targetID: targetID))
        return BasicEndpoint(
            path: "/v5/sessions/\(kind.pathComponent)/play",
            method: .post,
            headers: ["X-MS-Device-Info": StreamingDeviceInfo.defaultJSON],
            body: body
        )
    }

    static func state(kind: StreamingKind, sessionID: String) -> BasicEndpoint {
        BasicEndpoint(path: "/v5/sessions/\(kind.pathComponent)/\(sessionID)/state")
    }

    static func keepAlive(kind: StreamingKind, sessionID: String) -> BasicEndpoint {
        BasicEndpoint(
            path: "/v5/sessions/\(kind.pathComponent)/\(sessionID)/keepalive",
            method: .post
        )
    }

    static func stop(kind: StreamingKind, sessionID: String) -> BasicEndpoint {
        BasicEndpoint(
            path: "/v5/sessions/\(kind.pathComponent)/\(sessionID)",
            method: .delete
        )
    }
}

private extension StreamingKind {
    var pathComponent: String {
        switch self {
        case .home: "home"
        case .cloud: "cloud"
        }
    }
}

private struct StreamingPlayRequest: Encodable {
    struct Settings: Encodable {
        let nanoVersion = "V3;WebrtcTransport.dll"
        let enableTextToSpeech = false
        let highContrast = 0
        let locale = "en-US"
        let useIceConnection = false
        let timezoneOffsetMinutes = 120
        let sdkType = "web"
        let osName = "windows"
    }

    let titleID: String
    let systemUpdateGroup = ""
    let clientSessionID = ""
    let settings = Settings()
    let serverID: String
    let fallbackRegionNames: [String] = []

    init(kind: StreamingKind, targetID: String) {
        self.titleID = kind == .cloud ? targetID : ""
        self.serverID = kind == .home ? targetID : ""
    }

    enum CodingKeys: String, CodingKey {
        case titleID = "titleId"
        case systemUpdateGroup
        case clientSessionID = "clientSessionId"
        case settings
        case serverID = "serverId"
        case fallbackRegionNames
    }
}

private enum StreamingDeviceInfo {
    static let defaultJSON = """
    {"appInfo":{"env":{"clientAppId":"www.xbox.com","clientAppType":"browser","clientAppVersion":"26.1.97","clientSdkVersion":"10.3.7","httpEnvironment":"prod","sdkInstallId":""}},"dev":{"hw":{"make":"Microsoft","model":"unknown","sdktype":"web"},"os":{"name":"windows","ver":"22631.2715","platform":"desktop"},"displayInfo":{"dimensions":{"widthInPixels":1920,"heightInPixels":1080},"pixelDensity":{"dpiX":1,"dpiY":1}},"browser":{"browserName":"chrome","browserVersion":"130.0"}}}
    """
}

private struct StreamingPlayResponse: Decodable {
    let sessionPath: String
    let sessionID: String?
    let state: String?
    let errorDetails: StreamingErrorPayload?

    enum CodingKeys: String, CodingKey {
        case sessionPath
        case sessionID = "sessionId"
        case state
        case errorDetails
    }

    func asStreamingSession(kind: StreamingKind, targetID: String) -> StreamingSession {
        let id = sessionID ?? sessionPath.split(separator: "/").last.map(String.init) ?? ""
        return StreamingSession(
            id: id,
            targetID: targetID,
            sessionPath: sessionPath,
            kind: kind,
            state: StreamingStateMapper.map(state),
            errorDetails: errorDetails?.asErrorDetails()
        )
    }
}

private struct StreamingStateResponse: Decodable {
    let state: String
    let waitingTimeInMinutes: Int?
    let errorDetails: StreamingErrorPayload?

    func asStreamingSession(
        id: String,
        targetID: String,
        sessionPath: String,
        kind: StreamingKind
    ) -> StreamingSession {
        StreamingSession(
            id: id,
            targetID: targetID,
            sessionPath: sessionPath,
            kind: kind,
            state: StreamingStateMapper.map(state),
            waitingTimeMinutes: waitingTimeInMinutes,
            errorDetails: errorDetails?.asErrorDetails()
        )
    }
}

private struct StreamingErrorPayload: Decodable {
    let code: String?
    let message: String?

    func asErrorDetails() -> StreamingErrorDetails {
        StreamingErrorDetails(
            code: code ?? "streaming_error",
            message: message ?? "Streaming session failed."
        )
    }
}

private enum StreamingStateMapper {
    static func map(_ state: String?) -> StreamingState {
        switch state {
        case "Provisioned":
            return .started
        case "ReadyToConnect":
            return .readyToConnect
        case "Provisioning":
            return .pending
        case "WaitingForResources":
            return .queued
        case "Failed":
            return .failed
        default:
            return .pending
        }
    }
}

enum StreamingFixtures {
    static let pendingSession = StreamingSession(
        id: "stream-session-1",
        targetID: "target-1",
        sessionPath: "/sessions/stream-session-1",
        kind: .cloud,
        state: .pending
    )

    static let queuedSession = StreamingSession(
        id: "stream-session-1",
        targetID: "target-1",
        sessionPath: "/sessions/stream-session-1",
        kind: .cloud,
        state: .queued,
        waitingTimeMinutes: 2
    )

    static let readySession = StreamingSession(
        id: "stream-session-1",
        targetID: "target-1",
        sessionPath: "/sessions/stream-session-1",
        kind: .cloud,
        state: .readyToConnect
    )

    static let failedSession = StreamingSession(
        id: "stream-session-1",
        targetID: "target-1",
        sessionPath: "/sessions/stream-session-1",
        kind: .cloud,
        state: .failed,
        errorDetails: StreamingErrorDetails(code: "session_failed", message: "Provisioning failed")
    )

    static let readySequence = [
        queuedSession,
        readySession
    ]
}
