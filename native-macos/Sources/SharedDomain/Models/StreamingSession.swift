import Foundation

public enum StreamingKind: String, Codable, Equatable, Sendable, CaseIterable {
    case home
    case cloud
}

public enum StreamingState: String, Codable, Equatable, Sendable, CaseIterable {
    case pending
    case queued
    case readyToConnect
    case started
    case failed
    case stopped
}

public struct StreamingErrorDetails: Codable, Equatable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct StreamingSession: Codable, Equatable, Sendable {
    public let id: String
    public let targetID: String
    public let sessionPath: String
    public let kind: StreamingKind
    public let state: StreamingState
    public let waitingTimeMinutes: Int?
    public let errorDetails: StreamingErrorDetails?

    public init(
        id: String,
        targetID: String,
        sessionPath: String,
        kind: StreamingKind,
        state: StreamingState = .pending,
        waitingTimeMinutes: Int? = nil,
        errorDetails: StreamingErrorDetails? = nil
    ) {
        self.id = id
        self.targetID = targetID
        self.sessionPath = sessionPath
        self.kind = kind
        self.state = state
        self.waitingTimeMinutes = waitingTimeMinutes
        self.errorDetails = errorDetails
    }
}
