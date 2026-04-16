import SharedDomain

public struct StreamingEngineCapabilities: Equatable, Sendable {
    public let supportsVideo: Bool
    public let supportsAudio: Bool
    public let supportsPointerInput: Bool
    public let supportsControllerInput: Bool
    public let supportsNativeOverlay: Bool
    public let supportsRumble: Bool

    public init(
        supportsVideo: Bool,
        supportsAudio: Bool,
        supportsPointerInput: Bool,
        supportsControllerInput: Bool,
        supportsNativeOverlay: Bool,
        supportsRumble: Bool
    ) {
        self.supportsVideo = supportsVideo
        self.supportsAudio = supportsAudio
        self.supportsPointerInput = supportsPointerInput
        self.supportsControllerInput = supportsControllerInput
        self.supportsNativeOverlay = supportsNativeOverlay
        self.supportsRumble = supportsRumble
    }
}

public protocol StreamingEngineProtocol: Sendable {
    var capabilities: StreamingEngineCapabilities { get }
    func prepare(session: StreamingSession) async throws
    func start(session: StreamingSession, signaling: StreamingSignalingClient?) async throws
    func sendControlEvent(_ event: StreamingControlEvent) async
    func stop() async
}

public extension StreamingEngineProtocol {
    func start(session: StreamingSession) async throws {
        try await start(session: session, signaling: nil)
    }

    func sendControlEvent(_ event: StreamingControlEvent) async {}
}

public protocol StreamingSignalingClient: Sendable {
    func exchangeSDP(sessionID: String, offerSDP: String) async throws -> StreamingSDPAnswer
    func exchangeICE(sessionID: String, candidate: String) async throws -> [StreamingICECandidate]
}

public struct PreviewStreamingEngine: StreamingEngineProtocol {
    public let capabilities = StreamingEngineCapabilities(
        supportsVideo: true,
        supportsAudio: true,
        supportsPointerInput: false,
        supportsControllerInput: true,
        supportsNativeOverlay: false,
        supportsRumble: false
    )

    public init() {}

    public func prepare(session: StreamingSession) async throws {}

    public func start(session: StreamingSession, signaling: StreamingSignalingClient?) async throws {}

    public func sendControlEvent(_ event: StreamingControlEvent) async {}

    public func stop() async {}
}
