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
    #expect(await engine.signalingStartCalls == 1)
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
    #expect(await engine.signalingStartCalls == 1)
}

@Test
func streamingServiceStartsEngineWhenRemoteSessionIsAlreadyStarted() async throws {
    let repository = TestStreamingRepository(
        createdSession: StreamingFixtures.pendingSession,
        refreshResponses: [StreamingFixtures.startedSession]
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

    #expect(state.session?.state == .started)
    #expect(await repository.connectCalls == [])
    #expect(await engine.prepareCalls == 1)
    #expect(await engine.startCalls == 1)
    #expect(await engine.signalingStartCalls == 1)
}

@Test
func streamingServiceStartsKeepAliveLoopAfterEngineStart() async throws {
    let repository = TestStreamingRepository(
        createdSession: StreamingFixtures.pendingSession,
        refreshResponses: [StreamingFixtures.startedSession]
    )
    let service = StreamingService(
        repository: repository,
        engine: TestStreamingEngine(),
        monitor: StreamingSessionMonitor(
            repository: repository,
            maxAttempts: 1,
            pollIntervalNanoseconds: 1_000_000
        ),
        keepAliveIntervalNanoseconds: 1_000_000
    )

    _ = try await service.startStreaming(kind: .cloud, targetID: "title-1")
    try await Task.sleep(nanoseconds: 5_000_000)

    #expect(await repository.keepAliveCalls.isEmpty == false)
}

@Test
func streamingServiceCancelsKeepAliveLoopWhenStopping() async throws {
    let repository = TestStreamingRepository(
        createdSession: StreamingFixtures.pendingSession,
        refreshResponses: [StreamingFixtures.startedSession]
    )
    let service = StreamingService(
        repository: repository,
        engine: TestStreamingEngine(),
        monitor: StreamingSessionMonitor(
            repository: repository,
            maxAttempts: 1,
            pollIntervalNanoseconds: 1_000_000
        ),
        keepAliveIntervalNanoseconds: 1_000_000
    )

    _ = try await service.startStreaming(kind: .cloud, targetID: "title-1")
    try await Task.sleep(nanoseconds: 5_000_000)
    _ = try await service.stopStreaming(sessionID: "stream-session-1")
    let countAfterStop = await repository.keepAliveCalls.count
    try await Task.sleep(nanoseconds: 5_000_000)

    #expect(await repository.keepAliveCalls.count == countAfterStop)
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

@Test
func streamingServiceExposesSignalingExchangeOperations() async throws {
    let repository = TestStreamingRepository(
        createdSession: StreamingFixtures.pendingSession,
        refreshResponses: []
    )
    let service = StreamingService(
        repository: repository,
        engine: TestStreamingEngine()
    )

    let answer = try await service.exchangeSDP(sessionID: "stream-session-1", offerSDP: "v=0\r\nlocal-offer")
    let candidates = try await service.exchangeICE(
        sessionID: "stream-session-1",
        candidate: "a=candidate:1 1 UDP 1 10.0.0.1 9002 typ host"
    )

    #expect(answer.sdp == "v=0\r\ntest-answer")
    #expect(candidates.first?.candidate == "a=candidate:1 1 UDP 1 127.0.0.1 9002 typ host")
    #expect(await repository.sdpExchangeCalls == ["stream-session-1:v=0\r\nlocal-offer"])
    #expect(await repository.iceExchangeCalls == ["stream-session-1:a=candidate:1 1 UDP 1 10.0.0.1 9002 typ host"])
}

@Test
func streamingServiceForwardsBatchIceCandidatesToRepository() async throws {
    let repository = TestStreamingRepository(
        createdSession: StreamingFixtures.pendingSession,
        refreshResponses: []
    )
    let service = StreamingService(
        repository: repository,
        engine: TestStreamingEngine()
    )

    _ = try await service.exchangeICE(
        sessionID: "stream-session-1",
        candidates: [
            StreamingICECandidate(
                messageType: "iceCandidate",
                candidate: "a=candidate:1 1 UDP 1 10.0.0.1 9002 typ host",
                sdpMid: "0",
                sdpMLineIndex: "0"
            ),
            StreamingICECandidate(
                messageType: "iceCandidate",
                candidate: "a=candidate:2 1 UDP 1 10.0.0.2 9002 typ host",
                sdpMid: "0",
                sdpMLineIndex: "0"
            )
        ]
    )

    #expect(await repository.iceBatchExchangeCalls == [
        "stream-session-1:a=candidate:1 1 UDP 1 10.0.0.1 9002 typ host|a=candidate:2 1 UDP 1 10.0.0.2 9002 typ host"
    ])
}

private actor TestStreamingRepository: StreamingRepository {
    let createdSession: StreamingSession
    let refreshResponses: [StreamingSession]
    let connectResponse: StreamingSession?
    var refreshIndex = 0
    var connectCalls: [String] = []
    var sdpExchangeCalls: [String] = []
    var iceExchangeCalls: [String] = []
    var iceBatchExchangeCalls: [String] = []
    var keepAliveCalls: [String] = []
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

    func exchangeSDP(sessionID: String, offerSDP: String) async throws -> StreamingSDPAnswer {
        sdpExchangeCalls.append("\(sessionID):\(offerSDP)")
        return StreamingSDPAnswer(messageType: "answer", sdp: "v=0\r\ntest-answer")
    }

    func exchangeICE(sessionID: String, candidate: String) async throws -> [StreamingICECandidate] {
        iceExchangeCalls.append("\(sessionID):\(candidate)")
        return [
            StreamingICECandidate(
                messageType: "iceCandidate",
                candidate: "a=candidate:1 1 UDP 1 127.0.0.1 9002 typ host",
                sdpMid: "0",
                sdpMLineIndex: "0"
            )
        ]
    }

    func exchangeICE(sessionID: String, candidates: [StreamingICECandidate]) async throws -> [StreamingICECandidate] {
        iceBatchExchangeCalls.append("\(sessionID):\(candidates.map(\.candidate).joined(separator: "|"))")
        return [
            StreamingICECandidate(
                messageType: "iceCandidate",
                candidate: "a=candidate:1 1 UDP 1 127.0.0.1 9002 typ host",
                sdpMid: "0",
                sdpMLineIndex: "0"
            )
        ]
    }

    func sendKeepAlive(sessionID: String) async throws {
        keepAliveCalls.append(sessionID)
    }

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
    var signalingStartCalls = 0
    var stopCalls = 0

    func prepare(session: StreamingSession) async throws {
        prepareCalls += 1
    }

    func start(session: StreamingSession, signaling: StreamingSignalingClient?) async throws {
        startCalls += 1
        if signaling != nil {
            signalingStartCalls += 1
        }
    }

    func stop() async {
        stopCalls += 1
    }
}
