import Foundation
import SharedDomain

public enum WebRTCConnectionState: String, Equatable, Sendable {
    case idle
    case prepared
    case negotiating
    case connected
    case disconnected
}

@MainActor
public final class WebRTCSession: @unchecked Sendable {
    public let id: String
    public private(set) var state: WebRTCConnectionState
    public private(set) var lastRumbleIntensity: Double?
    public private(set) var localOfferSDP: String?
    public private(set) var remoteAnswerSDP: String?
    public private(set) var localICECandidate: String?
    public private(set) var remoteICECandidates: [StreamingICECandidate] = []
    public private(set) var sentControlEvents: [StreamingControlEvent] = []

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

    public func performSignaling(session: StreamingSession, signaling: StreamingSignalingClient) async throws {
        if state == .idle {
            prepareConnection()
        }

        state = .negotiating
        let offer = makeLocalOffer(session: session)
        localOfferSDP = offer
        let answer = try await signaling.exchangeSDP(sessionID: session.id, offerSDP: offer)
        remoteAnswerSDP = answer.sdp

        let candidate = makeLocalICECandidate(session: session)
        localICECandidate = candidate
        remoteICECandidates = try await signaling.exchangeICE(sessionID: session.id, candidate: candidate)
        state = .connected
    }

    public func disconnect() {
        state = .disconnected
    }

    public func sendRumble(intensity: Double) {
        lastRumbleIntensity = intensity
    }

    public func sendControlEvent(_ event: StreamingControlEvent) {
        sentControlEvents.append(event)
    }

    // Temporary handshake payload until a native WebRTC stack owns offer creation.
    private func makeLocalOffer(session: StreamingSession) -> String {
        """
        v=0
        o=xstreaming-native 0 0 IN IP4 127.0.0.1
        s=XStreaming \(session.id)
        t=0 0
        a=group:BUNDLE 0
        m=application 9 UDP/DTLS/SCTP webrtc-datachannel
        a=mid:0
        """
    }

    // Temporary host candidate until ICE gathering comes from the native WebRTC stack.
    private func makeLocalICECandidate(session: StreamingSession) -> String {
        "a=candidate:\(session.id.hashValue.magnitude % 10_000) 1 UDP 1 127.0.0.1 9 typ host"
    }
}
