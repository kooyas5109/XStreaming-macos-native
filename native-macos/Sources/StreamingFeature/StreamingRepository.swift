import Foundation
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
