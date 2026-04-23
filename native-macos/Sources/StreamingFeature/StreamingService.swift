import Foundation
import SharedDomain
import SupportKit

public final class StreamingService: @unchecked Sendable, StreamingSignalingClient {
    private let repository: StreamingRepository
    private let engine: StreamingEngineProtocol
    private let monitor: StreamingSessionMonitor
    private let keepAliveIntervalNanoseconds: UInt64
    private let logger: AppLogger
    private var keepAliveTask: Task<Void, Never>?

    public init(
        repository: StreamingRepository,
        engine: StreamingEngineProtocol,
        monitor: StreamingSessionMonitor? = nil,
        keepAliveIntervalNanoseconds: UInt64 = 30_000_000_000,
        logger: AppLogger = AppLogger(category: "WebRTC")
    ) {
        self.repository = repository
        self.engine = engine
        self.monitor = monitor ?? StreamingSessionMonitor(repository: repository)
        self.keepAliveIntervalNanoseconds = keepAliveIntervalNanoseconds
        self.logger = logger
    }

    public func startStreaming(
        kind: StreamingKind,
        targetID: String
    ) async throws -> StreamingStateMachine.State {
        logger.info("Streaming start requested: kind=\(kind.rawValue), target=\(targetID)")
        let createdSession = try await repository.createSession(kind: kind, targetID: targetID)
        logger.info("Streaming session created: id=\(createdSession.id), state=\(createdSession.state.rawValue)")
        var state = StreamingStateMachine.reduce(.idle, event: .sessionCreated(createdSession))

        logger.info("Waiting for streaming session readiness: id=\(createdSession.id)")
        let terminalSession = try await monitor.waitUntilReady(sessionID: createdSession.id) { _ in }
        logger.info("Streaming session readiness reached: id=\(terminalSession.id), state=\(terminalSession.state.rawValue)")
        state = StreamingStateMachine.reduce(
            state,
            event: .remoteStateChanged(terminalSession.state.rawValue, session: terminalSession)
        )

        switch terminalSession.state {
        case .readyToConnect:
            logger.info("Connecting streaming session: id=\(terminalSession.id)")
            var connectedSession = try await repository.connectSession(sessionID: terminalSession.id)
            logger.info("Streaming session connect returned: id=\(connectedSession.id), state=\(connectedSession.state.rawValue)")
            state = StreamingStateMachine.reduce(
                state,
                event: .remoteStateChanged(connectedSession.state.rawValue, session: connectedSession)
            )

            if connectedSession.state == .readyToConnect || connectedSession.state == .pending || connectedSession.state == .queued {
                logger.info("Waiting for streaming session started state: id=\(terminalSession.id)")
                connectedSession = try await monitor.waitUntilStarted(sessionID: terminalSession.id) { _ in }
                logger.info("Streaming session started wait returned: id=\(connectedSession.id), state=\(connectedSession.state.rawValue)")
                state = StreamingStateMachine.reduce(
                    state,
                    event: .remoteStateChanged(connectedSession.state.rawValue, session: connectedSession)
                )
            }

            guard connectedSession.state == .started else {
                logger.error("Streaming session did not reach started state: id=\(connectedSession.id), state=\(connectedSession.state.rawValue)")
                return state
            }

            return try await startEngine(for: connectedSession, from: state)

        case .started:
            logger.info("Streaming session already started: id=\(terminalSession.id)")
            return try await startEngine(for: terminalSession, from: state)

        case .failed:
            logger.error("Streaming session failed before engine start: id=\(terminalSession.id), error=\(terminalSession.errorDetails?.message ?? "unknown")")
            return StreamingStateMachine.reduce(state, event: .failed(terminalSession.errorDetails))

        case .stopped:
            logger.info("Streaming session stopped before engine start: id=\(terminalSession.id)")
            return .stopped

        case .pending, .queued:
            logger.info("Streaming session still pending after readiness wait: id=\(terminalSession.id), state=\(terminalSession.state.rawValue)")
            return state
        }
    }

    public func sendKeepAlive(sessionID: String) async throws {
        try await repository.sendKeepAlive(sessionID: sessionID)
    }

    public func exchangeSDP(sessionID: String, offerSDP: String) async throws -> StreamingSDPAnswer {
        logger.info("Streaming SDP exchange requested: id=\(sessionID), offerBytes=\(offerSDP.utf8.count)")
        return try await repository.exchangeSDP(sessionID: sessionID, offerSDP: offerSDP)
    }

    public func exchangeICE(sessionID: String, candidate: String) async throws -> [StreamingICECandidate] {
        logger.info("Streaming ICE exchange requested: id=\(sessionID), candidateBytes=\(candidate.utf8.count)")
        return try await repository.exchangeICE(sessionID: sessionID, candidate: candidate)
    }

    public func exchangeICE(sessionID: String, candidates: [StreamingICECandidate]) async throws -> [StreamingICECandidate] {
        logger.info("Streaming ICE batch exchange requested: id=\(sessionID), count=\(candidates.count)")
        return try await repository.exchangeICE(sessionID: sessionID, candidates: candidates)
    }

    public func stopStreaming(sessionID: String) async throws -> StreamingStateMachine.State {
        cancelKeepAliveLoop()
        try await repository.stopSession(sessionID: sessionID)
        await engine.stop()
        return StreamingStateMachine.reduce(.idle, event: .stopped)
    }

    private func startEngine(
        for session: StreamingSession,
        from state: StreamingStateMachine.State
    ) async throws -> StreamingStateMachine.State {
        logger.info("Preparing streaming engine: id=\(session.id)")
        try await engine.prepare(session: session)
        let preparedState = StreamingStateMachine.reduce(state, event: .enginePrepared)

        logger.info("Starting streaming engine: id=\(session.id)")
        try await engine.start(session: session, signaling: self)
        logger.info("Streaming engine start returned: id=\(session.id)")
        startKeepAliveLoop(sessionID: session.id)
        return StreamingStateMachine.reduce(preparedState, event: .engineStarted)
    }

    private func startKeepAliveLoop(sessionID: String) {
        cancelKeepAliveLoop()
        let repository = repository
        let interval = keepAliveIntervalNanoseconds
        keepAliveTask = Task {
            while Task.isCancelled == false {
                do {
                    try await repository.sendKeepAlive(sessionID: sessionID)
                } catch {
                    logger.error("Streaming keepalive failed: id=\(sessionID), error=\(error.localizedDescription)")
                }
                do {
                    try await Task.sleep(nanoseconds: interval)
                } catch {
                    return
                }
            }
        }
    }

    private func cancelKeepAliveLoop() {
        keepAliveTask?.cancel()
        keepAliveTask = nil
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
