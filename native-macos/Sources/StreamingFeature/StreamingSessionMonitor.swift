import Foundation
import SharedDomain

public final class StreamingSessionMonitor: @unchecked Sendable {
    private let repository: StreamingRepository
    private let maxAttempts: Int
    private let pollIntervalNanoseconds: UInt64

    public init(
        repository: StreamingRepository,
        maxAttempts: Int = 6,
        pollIntervalNanoseconds: UInt64 = 50_000_000
    ) {
        self.repository = repository
        self.maxAttempts = maxAttempts
        self.pollIntervalNanoseconds = pollIntervalNanoseconds
    }

    public func waitUntilReady(
        sessionID: String,
        onUpdate: (StreamingSession) -> Void
    ) async throws -> StreamingSession {
        var attempts = 0

        while attempts < maxAttempts {
            let session = try await repository.refreshSession(sessionID: sessionID)
            onUpdate(session)

            switch session.state {
            case .readyToConnect, .started, .failed, .stopped:
                return session
            case .pending, .queued:
                attempts += 1
                if attempts < maxAttempts {
                    try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
                }
            }
        }

        return try await repository.refreshSession(sessionID: sessionID)
    }
}
