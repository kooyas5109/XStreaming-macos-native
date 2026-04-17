import Foundation
import NetworkingKit
import PersistenceKit
import SharedDomain

public protocol StreamingRepository: StreamingSignalingClient {
    func createSession(kind: StreamingKind, targetID: String) async throws -> StreamingSession
    func refreshSession(sessionID: String) async throws -> StreamingSession
    func connectSession(sessionID: String) async throws -> StreamingSession
    func exchangeSDP(sessionID: String, offerSDP: String) async throws -> StreamingSDPAnswer
    func exchangeICE(sessionID: String, candidate: String) async throws -> [StreamingICECandidate]
    func exchangeICE(sessionID: String, candidates: [StreamingICECandidate]) async throws -> [StreamingICECandidate]
    func sendKeepAlive(sessionID: String) async throws
    func stopSession(sessionID: String) async throws
}

public extension StreamingRepository {
    func exchangeICE(sessionID: String, candidates: [StreamingICECandidate]) async throws -> [StreamingICECandidate] {
        guard let firstCandidate = candidates.first else {
            return []
        }
        return try await exchangeICE(sessionID: sessionID, candidate: firstCandidate.candidate)
    }
}

public struct StreamingSDPAnswer: Equatable, Sendable {
    public let messageType: String
    public let sdp: String

    public init(messageType: String, sdp: String) {
        self.messageType = messageType
        self.sdp = sdp
    }
}

public struct StreamingICECandidate: Equatable, Sendable {
    public let messageType: String
    public let candidate: String
    public let sdpMid: String?
    public let sdpMLineIndex: String?

    public init(
        messageType: String,
        candidate: String,
        sdpMid: String? = nil,
        sdpMLineIndex: String? = nil
    ) {
        self.messageType = messageType
        self.candidate = candidate
        self.sdpMid = sdpMid
        self.sdpMLineIndex = sdpMLineIndex
    }
}

public struct StreamingICECandidateProcessor: Sendable {
    public init() {}

    public func normalizedRemoteCandidates(
        _ candidates: [StreamingICECandidate],
        preferIPv6: Bool = false
    ) -> [StreamingICECandidate] {
        var expanded: [ParsedICECandidate] = []

        for candidate in candidates where candidate.candidate != "a=end-of-candidates" {
            if let parsed = ParsedICECandidate(candidate: candidate) {
                if let teredo = teredoCandidate(from: parsed) {
                    expanded.append(teredo.hostCandidate(port: "9002"))
                    expanded.append(teredo.hostCandidate(port: teredo.port))
                }
                expanded.append(parsed)
            }
        }

        if preferIPv6 {
            expanded.sort { first, second in
                if first.ip.contains(":") == second.ip.contains(":") {
                    return first.ip < second.ip
                }
                return first.ip.contains(":") && second.ip.contains(":") == false
            }
        }

        return expanded.enumerated().map { index, candidate in
            candidate.rewriting(
                foundation: index + 1,
                priority: index == 0 ? "2130706431" : "1"
            ).domainCandidate()
        } + [
            StreamingICECandidate(
                messageType: "iceCandidate",
                candidate: "a=end-of-candidates",
                sdpMid: "0",
                sdpMLineIndex: "0"
            )
        ]
    }

    private func teredoCandidate(from candidate: ParsedICECandidate) -> TeredoAddress? {
        guard candidate.ip.lowercased().hasPrefix("2001:") else {
            return nil
        }
        return TeredoAddress(ipv6Address: candidate.ip)
    }
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

    public func connectSession(sessionID: String) async throws -> StreamingSession {
        StreamingSession(
            id: sessionID,
            targetID: createdSession.targetID,
            sessionPath: createdSession.sessionPath,
            kind: createdSession.kind,
            state: .started
        )
    }

    public func exchangeSDP(sessionID: String, offerSDP: String) async throws -> StreamingSDPAnswer {
        StreamingSDPAnswer(messageType: "answer", sdp: "v=0\r\npreview-answer")
    }

    public func exchangeICE(sessionID: String, candidates: [StreamingICECandidate]) async throws -> [StreamingICECandidate] {
        [
            StreamingICECandidate(
                messageType: "iceCandidate",
                candidate: "a=candidate:1 1 UDP 1 127.0.0.1 9002 typ host",
                sdpMid: "0",
                sdpMLineIndex: "0"
            )
        ]
    }

    public func exchangeICE(sessionID: String, candidate: String) async throws -> [StreamingICECandidate] {
        try await exchangeICE(
            sessionID: sessionID,
            candidates: [
                StreamingICECandidate(
                    messageType: "iceCandidate",
                    candidate: candidate,
                    sdpMid: "0",
                    sdpMLineIndex: "0"
                )
            ]
        )
    }

    public func sendKeepAlive(sessionID: String) async throws {}

    public func stopSession(sessionID: String) async throws {}
}

public enum LiveStreamingRepositoryError: Error, Equatable {
    case missingToken(StreamingKind)
    case missingRefreshToken
    case missingSessionContext(String)
    case invalidBaseURI(String)
    case exchangeResponseUnavailable(String)
}

public final class LiveStreamingRepository: @unchecked Sendable, StreamingRepository {
    private let httpClient: HTTPClient
    private let tokenStore: TokenStoreProtocol
    private let defaultHomeBaseURI: String
    private let defaultCloudBaseURI: String
    private let maxExchangeAttempts: Int
    private let exchangePollIntervalNanoseconds: UInt64
    private let iceCandidateProcessor: StreamingICECandidateProcessor
    private let preferIPv6Candidates: Bool

    public init(
        httpClient: HTTPClient = HTTPClient(),
        tokenStore: TokenStoreProtocol,
        defaultHomeBaseURI: String = "https://xhome.gssv-play-prod.xboxlive.com",
        defaultCloudBaseURI: String = "https://xgpuweb.gssv-play-prod.xboxlive.com",
        maxExchangeAttempts: Int = 6,
        exchangePollIntervalNanoseconds: UInt64 = 1_000_000_000,
        iceCandidateProcessor: StreamingICECandidateProcessor = StreamingICECandidateProcessor(),
        preferIPv6Candidates: Bool = false
    ) {
        self.httpClient = httpClient
        self.tokenStore = tokenStore
        self.defaultHomeBaseURI = defaultHomeBaseURI
        self.defaultCloudBaseURI = defaultCloudBaseURI
        self.maxExchangeAttempts = maxExchangeAttempts
        self.exchangePollIntervalNanoseconds = exchangePollIntervalNanoseconds
        self.iceCandidateProcessor = iceCandidateProcessor
        self.preferIPv6Candidates = preferIPv6Candidates
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

    public func connectSession(sessionID: String) async throws -> StreamingSession {
        guard let context = sessionContexts[sessionID] else {
            throw LiveStreamingRepositoryError.missingSessionContext(sessionID)
        }

        let transferToken = try await fetchTransferToken()
        let request = try RequestBuilder.make(
            baseURL: context.baseURL,
            endpoint: try StreamingEndpoints.connect(
                kind: context.kind,
                sessionID: sessionID,
                transferToken: transferToken
            ),
            token: context.streamingToken
        )
        _ = try await httpClient.send(request)
        return try await refreshSession(sessionID: sessionID)
    }

    public func exchangeSDP(sessionID: String, offerSDP: String) async throws -> StreamingSDPAnswer {
        let context = try requireSessionContext(sessionID)
        let postRequest = try RequestBuilder.make(
            baseURL: context.baseURL,
            endpoint: try StreamingEndpoints.sdpOffer(
                kind: context.kind,
                sessionID: sessionID,
                offerSDP: offerSDP
            ),
            token: context.streamingToken
        )
        _ = try await httpClient.send(postRequest)

        return try await pollExchangeResponse(
            sessionID: sessionID,
            label: "sdp",
            endpoint: StreamingEndpoints.sdp(kind: context.kind, sessionID: sessionID),
            context: context,
            decode: decodeSDPAnswer
        )
    }

    public func exchangeICE(sessionID: String, candidates: [StreamingICECandidate]) async throws -> [StreamingICECandidate] {
        let context = try requireSessionContext(sessionID)
        let postRequest = try RequestBuilder.make(
            baseURL: context.baseURL,
            endpoint: try StreamingEndpoints.iceCandidate(
                kind: context.kind,
                sessionID: sessionID,
                candidates: candidates
            ),
            token: context.streamingToken
        )
        _ = try await httpClient.send(postRequest)

        let remoteCandidates: [StreamingICECandidate] = try await pollExchangeResponse(
            sessionID: sessionID,
            label: "ice",
            endpoint: StreamingEndpoints.ice(kind: context.kind, sessionID: sessionID),
            context: context,
            decode: decodeICECandidates
        )
        return iceCandidateProcessor.normalizedRemoteCandidates(remoteCandidates, preferIPv6: preferIPv6Candidates)
    }

    public func exchangeICE(sessionID: String, candidate: String) async throws -> [StreamingICECandidate] {
        try await exchangeICE(
            sessionID: sessionID,
            candidates: [
                StreamingICECandidate(
                    messageType: "iceCandidate",
                    candidate: candidate,
                    sdpMid: "0",
                    sdpMLineIndex: "0"
                )
            ]
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

    private func requireSessionContext(_ sessionID: String) throws -> StreamingSessionContext {
        guard let context = sessionContexts[sessionID] else {
            throw LiveStreamingRepositoryError.missingSessionContext(sessionID)
        }
        return context
    }

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

    private func fetchTransferToken() async throws -> String {
        guard
            let refreshToken = try tokenStore.load()?.refreshToken,
            refreshToken.isEmpty == false
        else {
            throw LiveStreamingRepositoryError.missingRefreshToken
        }

        let request = try RequestBuilder.make(
            baseURL: URL(string: "https://login.live.com")!,
            endpoint: StreamingEndpoints.transferToken(
                clientID: "1f907974-e22b-4810-a9de-d9647380c97e",
                refreshToken: refreshToken
            )
        )
        let response = try await httpClient.send(request)
        let payload = try httpClient.decode(StreamingTransferTokenResponse.self, from: response)
        return payload.livePassportToken
    }

    private func pollExchangeResponse<Response>(
        sessionID: String,
        label: String,
        endpoint: BasicEndpoint,
        context: StreamingSessionContext,
        decode: (String) throws -> Response
    ) async throws -> Response {
        var attempts = 0

        while attempts < maxExchangeAttempts {
            let request = try RequestBuilder.make(
                baseURL: context.baseURL,
                endpoint: endpoint,
                token: context.streamingToken
            )
            let response = try await httpClient.send(request)

            if response.data.isEmpty == false,
               let payload = try? httpClient.decode(StreamingExchangeResponse.self, from: response),
               let exchangeResponse = payload.exchangeResponse,
               exchangeResponse.isEmpty == false {
                return try decode(exchangeResponse)
            }

            attempts += 1
            if attempts < maxExchangeAttempts {
                try await Task.sleep(nanoseconds: exchangePollIntervalNanoseconds)
            }
        }

        throw LiveStreamingRepositoryError.exchangeResponseUnavailable("\(label):\(sessionID)")
    }

    private func decodeSDPAnswer(_ value: String) throws -> StreamingSDPAnswer {
        let payload = try JSONDecoder().decode(StreamingSDPAnswerPayload.self, from: Data(value.utf8))
        return payload.asDomain()
    }

    private func decodeICECandidates(_ value: String) throws -> [StreamingICECandidate] {
        if let candidates = try? JSONDecoder().decode([StreamingICECandidatePayload].self, from: Data(value.utf8)) {
            return candidates.map { $0.asDomain() }
        }

        let object = try JSONDecoder().decode([String: StreamingICECandidatePayload].self, from: Data(value.utf8))
        return object
            .sorted { $0.key < $1.key }
            .map { $0.value.asDomain() }
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

    static func connect(kind: StreamingKind, sessionID: String, transferToken: String) throws -> BasicEndpoint {
        let body = try JSONEncoder().encode(StreamingConnectRequest(userToken: transferToken))
        return BasicEndpoint(
            path: "/v5/sessions/\(kind.pathComponent)/\(sessionID)/connect",
            method: .post,
            body: body
        )
    }

    static func sdp(kind: StreamingKind, sessionID: String) -> BasicEndpoint {
        BasicEndpoint(path: "/v5/sessions/\(kind.pathComponent)/\(sessionID)/sdp")
    }

    static func sdpOffer(kind: StreamingKind, sessionID: String, offerSDP: String) throws -> BasicEndpoint {
        let body = try JSONEncoder().encode(StreamingSDPOfferRequest(sdp: offerSDP))
        return BasicEndpoint(
            path: "/v5/sessions/\(kind.pathComponent)/\(sessionID)/sdp",
            method: .post,
            body: body
        )
    }

    static func ice(kind: StreamingKind, sessionID: String) -> BasicEndpoint {
        BasicEndpoint(path: "/v5/sessions/\(kind.pathComponent)/\(sessionID)/ice")
    }

    static func iceCandidate(kind: StreamingKind, sessionID: String, candidates: [StreamingICECandidate]) throws -> BasicEndpoint {
        let body = try JSONEncoder().encode(StreamingICECandidateRequest(candidates: candidates))
        return BasicEndpoint(
            path: "/v5/sessions/\(kind.pathComponent)/\(sessionID)/ice",
            method: .post,
            body: body
        )
    }

    static func stop(kind: StreamingKind, sessionID: String) -> BasicEndpoint {
        BasicEndpoint(
            path: "/v5/sessions/\(kind.pathComponent)/\(sessionID)",
            method: .delete
        )
    }

    static func transferToken(clientID: String, refreshToken: String) -> BasicEndpoint {
        let body = [
            ("client_id", clientID),
            ("grant_type", "refresh_token"),
            ("scope", "service::http://Passport.NET/purpose::PURPOSE_XBOX_CLOUD_CONSOLE_TRANSFER_TOKEN"),
            ("refresh_token", refreshToken),
            ("code", ""),
            ("code_verifier", ""),
            ("redirect_uri", "")
        ]
        .map { key, value in
            "\(key)=\(value.formURLEncoded())"
        }
        .joined(separator: "&")

        return BasicEndpoint(
            path: "/oauth20_token.srf",
            method: .post,
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Cache-Control": "no-store, must-revalidate, no-cache"
            ],
            body: Data(body.utf8)
        )
    }
}

private extension String {
    func formURLEncoded() -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
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

private struct StreamingConnectRequest: Encodable {
    let userToken: String
}

private struct StreamingSDPOfferRequest: Encodable {
    struct Configuration: Encodable {
        struct ChatConfiguration: Encodable {
            struct Format: Encodable {
                let codec = "opus"
                let container = "webm"
            }

            let bytesPerSample = 2
            let expectedClipDurationMs = 20
            let format = Format()
            let numChannels = 1
            let sampleFrequencyHz = 24000
        }

        struct VersionRange: Encodable {
            let minVersion: Int
            let maxVersion: Int
        }

        let chatConfiguration = ChatConfiguration()
        let chat = VersionRange(minVersion: 1, maxVersion: 1)
        let control = VersionRange(minVersion: 1, maxVersion: 3)
        let input = VersionRange(minVersion: 1, maxVersion: 8)
        let message = VersionRange(minVersion: 1, maxVersion: 1)
    }

    let messageType = "offer"
    let sdp: String
    let configuration = Configuration()
}

private struct StreamingICECandidateRequest: Encodable {
    let messageType = "iceCandidate"
    let candidate: [Payload]

    init(candidates: [StreamingICECandidate]) {
        candidate = candidates.map(Payload.init(candidate:))
    }

    struct Payload: Encodable {
        let candidate: String
        let sdpMLineIndex: FlexibleIntegerString?
        let sdpMid: String?

        init(candidate: StreamingICECandidate) {
            self.candidate = candidate.candidate
            self.sdpMLineIndex = candidate.sdpMLineIndex.map(FlexibleIntegerString.init(value:))
            self.sdpMid = candidate.sdpMid
        }
    }
}

private struct StreamingTransferTokenResponse: Decodable {
    let livePassportToken: String

    enum CodingKeys: String, CodingKey {
        case livePassportToken = "lpt"
    }
}

private struct StreamingExchangeResponse: Decodable {
    let exchangeResponse: String?
}

private struct StreamingSDPAnswerPayload: Decodable {
    let messageType: String?
    let sdp: String

    func asDomain() -> StreamingSDPAnswer {
        StreamingSDPAnswer(messageType: messageType ?? "answer", sdp: sdp)
    }
}

private struct StreamingICECandidatePayload: Decodable {
    let messageType: String?
    let candidate: String
    let sdpMid: String?
    let sdpMLineIndex: FlexibleString?

    func asDomain() -> StreamingICECandidate {
        StreamingICECandidate(
            messageType: messageType ?? "iceCandidate",
            candidate: candidate,
            sdpMid: sdpMid,
            sdpMLineIndex: sdpMLineIndex?.value
        )
    }
}

private struct FlexibleString: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = String(try container.decode(Int.self))
        }
    }
}

private struct FlexibleIntegerString: Encodable {
    let value: String

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intValue = Int(value) {
            try container.encode(intValue)
        } else {
            try container.encode(value)
        }
    }
}

private struct ParsedICECandidate: Equatable {
    let messageType: String
    let foundation: String
    let component: String
    let transport: String
    let priority: String
    let ip: String
    let port: String
    let remainder: String
    let sdpMid: String?
    let sdpMLineIndex: String?

    init?(candidate: StreamingICECandidate) {
        let raw = candidate.candidate
        let normalized = raw.hasPrefix("a=") ? String(raw.dropFirst(2)) : raw
        let parts = normalized.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 8, parts[0].hasPrefix("candidate:") else {
            return nil
        }

        foundation = String(parts[0].dropFirst("candidate:".count))
        component = parts[1]
        transport = parts[2]
        priority = parts[3]
        ip = parts[4]
        port = parts[5]
        remainder = parts.dropFirst(6).joined(separator: " ")
        messageType = candidate.messageType
        sdpMid = candidate.sdpMid
        sdpMLineIndex = candidate.sdpMLineIndex
    }

    init(
        messageType: String,
        foundation: String,
        component: String,
        transport: String,
        priority: String,
        ip: String,
        port: String,
        remainder: String,
        sdpMid: String?,
        sdpMLineIndex: String?
    ) {
        self.messageType = messageType
        self.foundation = foundation
        self.component = component
        self.transport = transport
        self.priority = priority
        self.ip = ip
        self.port = port
        self.remainder = remainder
        self.sdpMid = sdpMid
        self.sdpMLineIndex = sdpMLineIndex
    }

    func rewriting(foundation: Int, priority: String) -> ParsedICECandidate {
        ParsedICECandidate(
            messageType: messageType,
            foundation: "\(foundation)",
            component: component,
            transport: transport,
            priority: priority,
            ip: ip,
            port: port,
            remainder: remainder,
            sdpMid: sdpMid,
            sdpMLineIndex: sdpMLineIndex
        )
    }

    func domainCandidate() -> StreamingICECandidate {
        StreamingICECandidate(
            messageType: messageType,
            candidate: "a=candidate:\(foundation) \(component) \(transport) \(priority) \(ip) \(port) \(remainder)",
            sdpMid: sdpMid,
            sdpMLineIndex: sdpMLineIndex
        )
    }
}

private struct TeredoAddress: Equatable {
    let clientIPv4: String
    let port: String

    init?(ipv6Address: String) {
        let expanded = Self.expandIPv6(ipv6Address)
        guard expanded.count == 8 else {
            return nil
        }

        let obfuscatedPort = UInt16(expanded[5], radix: 16) ?? 0
        port = "\(~obfuscatedPort)"

        let clientHigh = UInt16(expanded[6], radix: 16) ?? 0
        let clientLow = UInt16(expanded[7], radix: 16) ?? 0
        let bytes = [
            UInt8((clientHigh >> 8) & 0xff),
            UInt8(clientHigh & 0xff),
            UInt8((clientLow >> 8) & 0xff),
            UInt8(clientLow & 0xff)
        ].map { ~($0) }
        clientIPv4 = bytes.map(String.init).joined(separator: ".")
    }

    func hostCandidate(port: String) -> ParsedICECandidate {
        ParsedICECandidate(
            messageType: "iceCandidate",
            foundation: "0",
            component: "1",
            transport: "UDP",
            priority: "1",
            ip: clientIPv4,
            port: port,
            remainder: "typ host",
            sdpMid: "0",
            sdpMLineIndex: "0"
        )
    }

    private static func expandIPv6(_ address: String) -> [String] {
        if address.contains("::") == false {
            return address.split(separator: ":").map { String($0) }
        }

        let sides = address.components(separatedBy: "::")
        let left = sides.first?.split(separator: ":").map(String.init) ?? []
        let right = sides.dropFirst().first?.split(separator: ":").map(String.init) ?? []
        let missing = max(0, 8 - left.count - right.count)
        return left + Array(repeating: "0", count: missing) + right
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

    static let startedSession = StreamingSession(
        id: "stream-session-1",
        targetID: "target-1",
        sessionPath: "/sessions/stream-session-1",
        kind: .cloud,
        state: .started
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
