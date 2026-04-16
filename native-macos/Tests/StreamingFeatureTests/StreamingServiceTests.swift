import SharedDomain
import Testing
@testable import StreamingFeature

@Test
func streamingServiceStartsEngineWhenSessionBecomesReady() async throws {
    let repository = TestStreamingRepository(
        createdSession: StreamingFixtures.pendingSession,
        refreshResponses: [
            StreamingFixtures.queuedSession,
            StreamingFixtures.readySession
        ]
    )
    let engine = TestStreamingEngine()
    let service = StreamingService(
        repository: repository,
        engine: engine,
        monitor: StreamingSessionMonitor(
            repository: repository,
            maxAttempts: 3,
            pollIntervalNanoseconds: 1_000_000
        )
    )

    let state = try await service.startStreaming(kind: .cloud, targetID: "title-1")

    #expect(state.session?.state == .started)
    #expect(await repository.connectCalls == ["stream-session-1"])
    #expect(await engine.prepareCalls == 1)
    #expect(await engine.startCalls == 1)
}

@Test
func streamingServiceSurfacesFailedSessionWithoutStartingEngine() async throws {
    let repository = TestStreamingRepository(
        createdSession: StreamingFixtures.pendingSession,
        refreshResponses: [StreamingFixtures.failedSession]
    )
    let engine = TestStreamingEngine()
    let service = StreamingService(
        repository: repository,
        engine: engine,
        monitor: StreamingSessionMonitor(
            repository: repository,
            maxAttempts: 1,
            pollIntervalNanoseconds: 1_000_000
        )
    )

    let state = try await service.startStreaming(kind: .cloud, targetID: "title-1")

    #expect(state == .failed(StreamingFixtures.failedSession.errorDetails))
    #expect(await engine.prepareCalls == 0)
    #expect(await engine.startCalls == 0)
}

@Test
func streamingServiceWaitsForStartedStateAfterConnectHandshake() async throws {
    let repository = TestStreamingRepository(
        createdSession: StreamingFixtures.pendingSession,
        refreshResponses: [
            StreamingFixtures.readySession,
            StreamingFixtures.readySession,
            StreamingFixtures.startedSession
        ],
        connectResponse: StreamingFixtures.readySession
    )
    let engine = TestStreamingEngine()
    let service = StreamingService(
        repository: repository,
        engine: engine,
        monitor: StreamingSessionMonitor(
            repository: repository,
            maxAttempts: 3,
            pollIntervalNanoseconds: 1_000_000
        )
    )

    let state = try await service.startStreaming(kind: .cloud, targetID: "title-1")

    #expect(state.session?.state == .started)
    #expect(await repository.connectCalls == ["stream-session-1"])
    #expect(await engine.prepareCalls == 1)
    #expect(await engine.startCalls == 1)
}

@Test
func streamingServiceStopsRemoteSessionAndEngine() async throws {
    let repository = TestStreamingRepository(
        createdSession: StreamingFixtures.pendingSession,
        refreshResponses: [StreamingFixtures.readySession]
    )
    let engine = TestStreamingEngine()
    let service = StreamingService(
        repository: repository,
        engine: engine
    )

    let state = try await service.stopStreaming(sessionID: "stream-session-1")

    #expect(state == .stopped)
    #expect(await repository.stopCalls == ["stream-session-1"])
    #expect(await engine.stopCalls == 1)
}

private actor TestStreamingRepository: StreamingRepository {
    let createdSession: StreamingSession
    let refreshResponses: [StreamingSession]
    let connectResponse: StreamingSession?
    var refreshIndex = 0
    var connectCalls: [String] = []
    var stopCalls: [String] = []

    init(
        createdSession: StreamingSession,
        refreshResponses: [StreamingSession],
        connectResponse: StreamingSession? = nil
    ) {
        self.createdSession = createdSession
        self.refreshResponses = refreshResponses
        self.connectResponse = connectResponse
    }

    func createSession(kind: StreamingKind, targetID: String) async throws -> StreamingSession {
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

    func refreshSession(sessionID: String) async throws -> StreamingSession {
        guard refreshIndex < refreshResponses.count else {
            return refreshResponses.last ?? createdSession
        }

        let session = refreshResponses[refreshIndex]
        refreshIndex += 1
        return session
    }

    func connectSession(sessionID: String) async throws -> StreamingSession {
        connectCalls.append(sessionID)
        if let connectResponse {
            return connectResponse
        }

        return StreamingSession(
            id: sessionID,
            targetID: createdSession.targetID,
            sessionPath: createdSession.sessionPath,
            kind: createdSession.kind,
            state: .started
        )
    }

    func sendKeepAlive(sessionID: String) async throws {}

    func stopSession(sessionID: String) async throws {
        stopCalls.append(sessionID)
    }
}

private actor TestStreamingEngine: StreamingEngineProtocol {
    nonisolated let capabilities = StreamingEngineCapabilities(
        supportsVideo: true,
        supportsAudio: true,
        supportsPointerInput: false,
        supportsControllerInput: true,
        supportsNativeOverlay: false,
        supportsRumble: false
    )

    var prepareCalls = 0
    var startCalls = 0
    var stopCalls = 0

    func prepare(session: StreamingSession) async throws {
        prepareCalls += 1
    }

    func start(session: StreamingSession) async throws {
        startCalls += 1
    }

    func stop() async {
        stopCalls += 1
    }
}
