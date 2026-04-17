import Foundation

public struct StreamingControlChannelMessageEncoder: Sendable {
    public init() {}

    public func authorizationRequest() throws -> Data {
        try encode([
            "message": "authorizationRequest",
            "accessKey": "4BDB3609-C1F1-4195-9B37-FEFF45DA8B8E"
        ])
    }

    public func gamepadChanged(index: Int, wasAdded: Bool) throws -> Data {
        let payload: [String: AnyEncodable] = [
            "message": AnyEncodable("gamepadChanged"),
            "gamepadIndex": AnyEncodable(index),
            "wasAdded": AnyEncodable(wasAdded)
        ]
        return try JSONEncoder().encode(payload)
    }

    public func videoKeyframeRequested() throws -> Data {
        let payload: [String: AnyEncodable] = [
            "message": AnyEncodable("videoKeyframeRequested"),
            "ifrRequested": AnyEncodable(true)
        ]
        return try JSONEncoder().encode(payload)
    }

    private func encode(_ payload: [String: String]) throws -> Data {
        try JSONEncoder().encode(payload)
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: String) {
        encodeValue = { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
    }

    init(_ value: Int) {
        encodeValue = { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
    }

    init(_ value: Bool) {
        encodeValue = { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}
