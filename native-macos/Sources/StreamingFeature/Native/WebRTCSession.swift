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
    public private(set) var sentControlPayloads: [StreamingControlPayload] = []
    public private(set) var sentControlFrames: [Data] = []
    private let controlPayloadEncoder: StreamingControlPayloadEncoder
    private let inputPacketEncoder: StreamingInputPacketEncoder
    private let inputDataChannel: (any WebRTCDataChannelWriter)?
    private var inputSequence: UInt32 = 0

    public init(
        id: String = UUID().uuidString,
        state: WebRTCConnectionState = .idle,
        controlPayloadEncoder: StreamingControlPayloadEncoder = StreamingControlPayloadEncoder(),
        inputPacketEncoder: StreamingInputPacketEncoder = StreamingInputPacketEncoder(),
        inputDataChannel: (any WebRTCDataChannelWriter)? = nil
    ) {
        self.id = id
        self.state = state
        self.controlPayloadEncoder = controlPayloadEncoder
        self.inputPacketEncoder = inputPacketEncoder
        self.inputDataChannel = inputDataChannel
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

    public func sendControlEvent(_ event: StreamingControlEvent) async throws {
        let payload = controlPayloadEncoder.payload(for: event)
        let frame = inputFrame(for: event)

        if let frame, let inputDataChannel {
            guard await inputDataChannel.state == .open else {
                throw WebRTCDataChannelWriteError.channelNotOpen
            }
            try await inputDataChannel.send(frame)
        }

        sentControlEvents.append(event)
        sentControlPayloads.append(payload)
        if let frame {
            sentControlFrames.append(frame)
        }
    }

    public func sendInputMetadata() async throws {
        let frame = nextMetadataFrame()
        if let inputDataChannel {
            guard await inputDataChannel.state == .open else {
                throw WebRTCDataChannelWriteError.channelNotOpen
            }
            try await inputDataChannel.send(frame)
        }
        sentControlFrames.append(frame)
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

    private func inputFrame(for event: StreamingControlEvent) -> Data? {
        switch event {
        case .button(let button, let phase):
            inputSequence += 1
            var state = StreamingGamepadState()
            if phase == .began {
                if button == .leftTrigger {
                    state.leftTrigger = 1
                } else if button == .rightTrigger {
                    state.rightTrigger = 1
                } else {
                    state.buttons.insert(button)
                }
            }
            return inputPacketEncoder.gamepad(
                sequence: inputSequence,
                states: [state],
                timestampMilliseconds: currentTimestampMilliseconds()
            )
        case .microphone, .text:
            return nil
        }
    }

    private func nextMetadataFrame() -> Data {
        inputSequence += 1
        return inputPacketEncoder.metadata(
            sequence: inputSequence,
            timestampMilliseconds: currentTimestampMilliseconds()
        )
    }

    private func currentTimestampMilliseconds() -> Double {
        Date().timeIntervalSince1970 * 1000
    }
}
