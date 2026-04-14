import SharedDomain

public protocol StreamingEngineProtocol: Sendable {
    func prepare(session: StreamingSession) async throws
    func start(session: StreamingSession) async throws
    func stop() async
}

public struct PreviewStreamingEngine: StreamingEngineProtocol {
    public init() {}

    public func prepare(session: StreamingSession) async throws {}

    public func start(session: StreamingSession) async throws {}

    public func stop() async {}
}
