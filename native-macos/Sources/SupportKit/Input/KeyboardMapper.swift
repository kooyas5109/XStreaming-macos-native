import Foundation

public enum GameInputAction: String, Equatable, Sendable, CaseIterable {
    case buttonA
    case buttonB
    case buttonX
    case buttonY
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case leftShoulder
    case rightShoulder
    case leftTrigger
    case rightTrigger
    case leftThumbPress
    case rightThumbPress
    case leftThumbXAxisPlus
    case leftThumbXAxisMinus
    case leftThumbYAxisPlus
    case leftThumbYAxisMinus
    case rightThumbXAxisPlus
    case rightThumbXAxisMinus
    case rightThumbYAxisPlus
    case rightThumbYAxisMinus
    case view
    case menu
    case nexus
}

public struct KeyboardMapper: Sendable {
    private let mappings: [String: GameInputAction]

    public init(mappings: [String: GameInputAction]) {
        self.mappings = mappings
    }

    public func action(for key: String) -> GameInputAction? {
        mappings[key]
    }

    public static let `default` = KeyboardMapper(
        mappings: [
            "ArrowLeft": .dpadLeft,
            "ArrowUp": .dpadUp,
            "ArrowRight": .dpadRight,
            "ArrowDown": .dpadDown,
            "Enter": .buttonA,
            "k": .buttonA,
            "Backspace": .buttonB,
            "l": .buttonB,
            "j": .buttonX,
            "i": .buttonY,
            "2": .leftShoulder,
            "3": .rightShoulder,
            "1": .leftTrigger,
            "4": .rightTrigger,
            "5": .leftThumbPress,
            "6": .rightThumbPress,
            "a": .leftThumbXAxisPlus,
            "d": .leftThumbXAxisMinus,
            "w": .leftThumbYAxisPlus,
            "s": .leftThumbYAxisMinus,
            "f": .rightThumbXAxisPlus,
            "h": .rightThumbXAxisMinus,
            "t": .rightThumbYAxisPlus,
            "g": .rightThumbYAxisMinus,
            "v": .view,
            "m": .menu,
            "n": .nexus
        ]
    )
}
