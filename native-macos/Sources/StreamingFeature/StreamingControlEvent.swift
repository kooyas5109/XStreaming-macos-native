import Foundation
import SupportKit

public enum StreamingControlButton: String, Equatable, Sendable, CaseIterable {
    case buttonA = "A"
    case buttonB = "B"
    case buttonX = "X"
    case buttonY = "Y"
    case dpadUp = "DPadUp"
    case dpadDown = "DPadDown"
    case dpadLeft = "DPadLeft"
    case dpadRight = "DPadRight"
    case leftShoulder = "LeftShoulder"
    case rightShoulder = "RightShoulder"
    case leftTrigger = "LeftTrigger"
    case rightTrigger = "RightTrigger"
    case leftThumbPress = "LeftThumb"
    case rightThumbPress = "RightThumb"
    case view = "View"
    case menu = "Menu"
    case nexus = "Nexus"
}

public enum StreamingControlPhase: String, Equatable, Sendable {
    case began
    case ended
}

public enum StreamingControlEvent: Equatable, Sendable {
    case button(StreamingControlButton, StreamingControlPhase)
    case text(String)
    case microphone(active: Bool)
}

public struct StreamingControlPayload: Codable, Equatable, Sendable {
    public let type: String
    public let button: String?
    public let phase: String?
    public let text: String?
    public let active: Bool?

    public init(
        type: String,
        button: String? = nil,
        phase: String? = nil,
        text: String? = nil,
        active: Bool? = nil
    ) {
        self.type = type
        self.button = button
        self.phase = phase
        self.text = text
        self.active = active
    }

    public init(event: StreamingControlEvent) {
        switch event {
        case .button(let button, let phase):
            self.init(
                type: "button",
                button: button.rawValue,
                phase: phase.rawValue
            )
        case .text(let text):
            self.init(type: "text", text: text)
        case .microphone(let active):
            self.init(type: "microphone", active: active)
        }
    }
}

public struct StreamingControlPayloadEncoder: Sendable {
    public init() {}

    public func payload(for event: StreamingControlEvent) -> StreamingControlPayload {
        StreamingControlPayload(event: event)
    }
}

public struct StreamingInputTranslator: Sendable {
    public init() {}

    public func button(for action: GameInputAction) -> StreamingControlButton? {
        switch action {
        case .buttonA:
            return .buttonA
        case .buttonB:
            return .buttonB
        case .buttonX:
            return .buttonX
        case .buttonY:
            return .buttonY
        case .dpadUp:
            return .dpadUp
        case .dpadDown:
            return .dpadDown
        case .dpadLeft:
            return .dpadLeft
        case .dpadRight:
            return .dpadRight
        case .leftShoulder:
            return .leftShoulder
        case .rightShoulder:
            return .rightShoulder
        case .leftTrigger:
            return .leftTrigger
        case .rightTrigger:
            return .rightTrigger
        case .leftThumbPress:
            return .leftThumbPress
        case .rightThumbPress:
            return .rightThumbPress
        case .view:
            return .view
        case .menu:
            return .menu
        case .nexus:
            return .nexus
        case .leftThumbXAxisPlus,
             .leftThumbXAxisMinus,
             .leftThumbYAxisPlus,
             .leftThumbYAxisMinus,
             .rightThumbXAxisPlus,
             .rightThumbXAxisMinus,
             .rightThumbYAxisPlus,
             .rightThumbYAxisMinus:
            return nil
        }
    }

    public func events(
        for action: GameInputAction,
        phase: StreamingControlPhase
    ) -> [StreamingControlEvent] {
        guard let button = button(for: action) else {
            return []
        }

        return [.button(button, phase)]
    }
}
