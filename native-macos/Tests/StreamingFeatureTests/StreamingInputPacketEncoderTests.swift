import Foundation
import Testing
@testable import StreamingFeature

@Test
func inputPacketEncoderBuildsClientMetadataPacket() {
    let encoder = StreamingInputPacketEncoder()
    let data = encoder.metadata(sequence: 7, maxTouchpoints: 2, timestampMilliseconds: 12.5)

    #expect(data.count == 15)
    #expect(data.uint16(at: 0) == StreamingInputPacketEncoder.ReportType.clientMetadata.rawValue)
    #expect(data.uint32(at: 2) == 7)
    #expect(data.double(at: 6) == 12.5)
    #expect(data[14] == 2)
}

@Test
func inputPacketEncoderBuildsGamepadButtonPacket() {
    let encoder = StreamingInputPacketEncoder()
    let data = encoder.gamepad(
        sequence: 8,
        states: [
            StreamingGamepadState(buttons: [.nexus, .buttonA])
        ],
        timestampMilliseconds: 20
    )

    #expect(data.count == 38)
    #expect(data.uint16(at: 0) == StreamingInputPacketEncoder.ReportType.gamepad.rawValue)
    #expect(data.uint32(at: 2) == 8)
    #expect(data.double(at: 6) == 20)
    #expect(data[14] == 1)
    #expect(data[15] == 0)
    #expect(data.uint16(at: 16) == 18)
}

@Test
func inputPacketEncoderBuildsTriggerPacket() {
    let encoder = StreamingInputPacketEncoder()
    let data = encoder.gamepad(
        sequence: 9,
        states: [
            StreamingGamepadState(leftTrigger: 1, rightTrigger: 0.5)
        ],
        timestampMilliseconds: 21
    )

    #expect(data.uint16(at: 26) == 65535)
    #expect(data.uint16(at: 28) == 32767)
}

private extension Data {
    func uint16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uint32(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }

    func double(at offset: Int) -> Double {
        var bitPattern: UInt64 = 0
        for index in 0..<8 {
            bitPattern |= UInt64(self[offset + index]) << UInt64(index * 8)
        }
        return Double(bitPattern: bitPattern)
    }
}
