import Foundation
import SharedDomain

public final class StreamingService: @unchecked Sendable, StreamingSignalingClient {
    private let repository: StreamingRepository
    private let engine: StreamingEngineProtocol
    private let monitor: StreamingSessionMonitor

    public init(
        repository: StreamingRepository,
        engine: StreamingEngineProtocol,
        monitor: StreamingSessionMonitor? = nil
    ) {
        self.repository = repository
        self.engine = engine
        self.monitor = monitor ?? StreamingSessionMonitor(repository: repository)
    }

    public func startStreaming(
        kind: StreamingKind,
        targetID: String
    ) async throws -> StreamingStateMachine.State {
        let createdSession = try await repository.createSession(kind: kind, targetID: targetID)
        var state = StreamingStateMachine.reduce(.idle, event: .sessionCreated(createdSession))

        let terminalSession = try await monitor.waitUntilReady(sessionID: createdSession.id) { _ in }
        state = StreamingStateMachine.reduce(
            state,
            event: .remoteStateChanged(terminalSession.state.rawValue, session: terminalSession)
        )

        switch terminalSession.state {
        case .readyToConnect:
            var connectedSession = try await repository.connectSession(sessionID: terminalSession.id)
            state = StreamingStateMachine.reduce(
                state,
                event: .remoteStateChanged(connectedSession.state.rawValue, session: connectedSession)
            )

            if connectedSession.state == .readyToConnect || connectedSession.state == .pending || connectedSession.state == .queued {
                connectedSession = try await monitor.waitUntilStarted(sessionID: terminalSession.id) { _ in }
                state = StreamingStateMachine.reduce(
                    state,
                    event: .remoteStateChanged(connectedSession.state.rawValue, session: connectedSession)
                )
            }

            guard connectedSession.state == .started else {
                return state
            }

            return try await startEngine(for: connectedSession, from: state)

        case .started:
            return try await startEngine(for: terminalSession, from: state)

        case .failed:
            return StreamingStateMachine.reduce(state, event: .failed(terminalSession.errorDetails))

        case .stopped:
            return .stopped

        case .pending, .queued:
            return state
        }
    }

    public func sendKeepAlive(sessionID: String) async throws {
        try await repository.sendKeepAlive(sessionID: sessionID)
    }

    public func exchangeSDP(sessionID: String, offerSDP: String) async throws -> StreamingSDPAnswer {
        try await repository.exchangeSDP(sessionID: sessionID, offerSDP: offerSDP)
    }

    public func exchangeICE(sessionID: String, candidate: String) async throws -> [StreamingICECandidate] {
        try await repository.exchangeICE(sessionID: sessionID, candidate: candidate)
    }

    public func stopStreaming(sessionID: String) async throws -> StreamingStateMachine.State {
        try await repository.stopSession(sessionID: sessionID)
        await engine.stop()
        return StreamingStateMachine.reduce(.idle, event: .stopped)
    }

    private func startEngine(
        for session: StreamingSession,
        from state: StreamingStateMachine.State
    ) async throws -> StreamingStateMachine.State {
        try await engine.prepare(session: session)
        let preparedState = StreamingStateMachine.reduce(state, event: .enginePrepared)

        try await engine.start(session: session, signaling: self)
        return StreamingStateMachine.reduce(preparedState, event: .engineStarted)
    }

    public static func preview() -> StreamingService {
        let repository = PreviewStreamingRepository()
        return StreamingService(
            repository: repository,
            engine: PreviewStreamingEngine(),
            monitor: StreamingSessionMonitor(
                repository: repository,
                maxAttempts: 3,
                pollIntervalNanoseconds: 1_000_000
            )
        )
    }
}
