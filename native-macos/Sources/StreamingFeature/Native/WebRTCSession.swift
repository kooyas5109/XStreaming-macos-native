import Foundation

public enum WebRTCConnectionState: String, Equatable, Sendable {
    case idle
    case prepared
    case connected
    case disconnected
}

@MainActor
public final class WebRTCSession: @unchecked Sendable {
    public let id: String
    public private(set) var state: WebRTCConnectionState
    public private(set) var lastRumbleIntensity: Double?

    public init(
        id: String = UUID().uuidString,
        state: WebRTCConnectionState = .idle
    ) {
        self.id = id
        self.state = state
    }

    public func prepareConnection() {
        state = .prepared
    }

    public func connect() {
        if state == .idle {
            prepareConnection()
        }
        state = .connected
    }

    public func disconnect() {
        state = .disconnected
    }

    public func sendRumble(intensity: Double) {
        lastRumbleIntensity = intensity
    }
}
