import Foundation

public struct StreamingGamepadState: Equatable, Sendable {
    public var gamepadIndex: UInt8
    public var buttons: Set<StreamingControlButton>
    public var leftThumbX: Double
    public var leftThumbY: Double
    public var rightThumbX: Double
    public var rightThumbY: Double
    public var leftTrigger: Double
    public var rightTrigger: Double

    public init(
        gamepadIndex: UInt8 = 0,
        buttons: Set<StreamingControlButton> = [],
        leftThumbX: Double = 0,
        leftThumbY: Double = 0,
        rightThumbX: Double = 0,
        rightThumbY: Double = 0,
        leftTrigger: Double = 0,
        rightTrigger: Double = 0
    ) {
        self.gamepadIndex = gamepadIndex
        self.buttons = buttons
        self.leftThumbX = leftThumbX
        self.leftThumbY = leftThumbY
        self.rightThumbX = rightThumbX
        self.rightThumbY = rightThumbY
        self.leftTrigger = leftTrigger
        self.rightTrigger = rightTrigger
    }
}

public struct StreamingInputPacketEncoder: Sendable {
    public enum ReportType: UInt16, Sendable {
        case clientMetadata = 8
        case gamepad = 2
    }

    public init() {}

    public func metadata(sequence: UInt32, maxTouchpoints: UInt8 = 2, timestampMilliseconds: Double = 0) -> Data {
        var data = Data()
        data.appendLittleEndian(ReportType.clientMetadata.rawValue)
        data.appendLittleEndian(sequence)
        data.appendLittleEndian(timestampMilliseconds)
        data.append(maxTouchpoints)
        return data
    }

    public func gamepad(
        sequence: UInt32,
        states: [StreamingGamepadState],
        timestampMilliseconds: Double = 0
    ) -> Data {
        var data = Data()
        data.appendLittleEndian(ReportType.gamepad.rawValue)
        data.appendLittleEndian(sequence)
        data.appendLittleEndian(timestampMilliseconds)
        data.append(UInt8(states.count))

        for state in states {
            data.append(state.gamepadIndex)
            data.appendLittleEndian(buttonMask(for: state))
            data.appendLittleEndian(normalizeAxis(state.leftThumbX))
            data.appendLittleEndian(normalizeAxis(-state.leftThumbY))
            data.appendLittleEndian(normalizeAxis(state.rightThumbX))
            data.appendLittleEndian(normalizeAxis(-state.rightThumbY))
            data.appendLittleEndian(normalizeTrigger(state.leftTrigger))
            data.appendLittleEndian(normalizeTrigger(state.rightTrigger))
            data.appendLittleEndian(UInt32(0))
            data.appendBigEndian(UInt32(0))
        }

        return data
    }

    private func buttonMask(for state: StreamingGamepadState) -> UInt16 {
        var mask: UInt16 = 0
        if state.buttons.contains(.nexus) { mask |= 2 }
        if state.buttons.contains(.menu) { mask |= 4 }
        if state.buttons.contains(.view) { mask |= 8 }
        if state.buttons.contains(.buttonA) { mask |= 16 }
        if state.buttons.contains(.buttonB) { mask |= 32 }
        if state.buttons.contains(.buttonX) { mask |= 64 }
        if state.buttons.contains(.buttonY) { mask |= 128 }
        if state.buttons.contains(.dpadUp) { mask |= 256 }
        if state.buttons.contains(.dpadDown) { mask |= 512 }
        if state.buttons.contains(.dpadLeft) { mask |= 1024 }
        if state.buttons.contains(.dpadRight) { mask |= 2048 }
        if state.buttons.contains(.leftShoulder) { mask |= 4096 }
        if state.buttons.contains(.rightShoulder) { mask |= 8192 }
        if state.buttons.contains(.leftThumbPress) { mask |= 16384 }
        if state.buttons.contains(.rightThumbPress) { mask |= 32768 }
        return mask
    }

    private func normalizeAxis(_ value: Double) -> Int16 {
        let clamped = min(1, max(-1, value))
        return Int16(clamped * 32767)
    }

    private func normalizeTrigger(_ value: Double) -> UInt16 {
        let clamped = min(1, max(0, value))
        return UInt16(clamped * 65535)
    }
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendBigEndian(_ value: UInt32) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian(_ value: Int16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian(_ value: Double) {
        var bitPattern = value.bitPattern.littleEndian
        Swift.withUnsafeBytes(of: &bitPattern) { append(contentsOf: $0) }
    }
}
