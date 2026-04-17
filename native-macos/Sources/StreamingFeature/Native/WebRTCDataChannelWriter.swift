import Foundation

public enum WebRTCDataChannelState: Equatable, Sendable {
    case open
    case closed
}

public enum WebRTCDataChannelWriteError: Error, Equatable, Sendable {
    case channelNotOpen
}

public protocol WebRTCDataChannelWriter: Sendable {
    var state: WebRTCDataChannelState { get async }
    func send(_ data: Data) async throws
}
