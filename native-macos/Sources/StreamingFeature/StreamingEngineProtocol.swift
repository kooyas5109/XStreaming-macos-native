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
    func start(session: StreamingSession) async throws
    func stop() async
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

    public func start(session: StreamingSession) async throws {}

    public func stop() async {}
}
