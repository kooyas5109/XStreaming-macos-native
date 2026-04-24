import Foundation

public enum MouseKeyboardGamepadControl: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case buttonA
    case buttonB
    case buttonX
    case buttonY
    case leftShoulder
    case rightShoulder
    case leftTrigger
    case rightTrigger
    case view
    case menu
    case leftThumbPress
    case rightThumbPress
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case nexus
    case share
    case leftStickUp
    case leftStickDown
    case leftStickLeft
    case leftStickRight
    case rightStickUp
    case rightStickDown
    case rightStickLeft
    case rightStickRight
}

public enum MouseKeyboardMouseTarget: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case off
    case leftStick
    case rightStick
}

public struct MouseKeyboardMouseSettings: Codable, Equatable, Sendable {
    public var mapTo: MouseKeyboardMouseTarget
    public var sensitivityX: Double
    public var sensitivityY: Double
    public var deadzoneCounterweight: Double

    public init(
        mapTo: MouseKeyboardMouseTarget,
        sensitivityX: Double,
        sensitivityY: Double,
        deadzoneCounterweight: Double
    ) {
        self.mapTo = mapTo
        self.sensitivityX = sensitivityX
        self.sensitivityY = sensitivityY
        self.deadzoneCounterweight = deadzoneCounterweight
    }
}

public struct MouseKeyboardMappingProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var bindings: [MouseKeyboardGamepadControl: [String]]
    public var mouse: MouseKeyboardMouseSettings
    public var isBuiltIn: Bool

    public init(
        id: String,
        name: String,
        bindings: [MouseKeyboardGamepadControl: [String]],
        mouse: MouseKeyboardMouseSettings,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bindings = bindings
        self.mouse = mouse
        self.isBuiltIn = isBuiltIn
    }
}

public struct MouseKeyboardProfiles: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var selectedProfileID: String
    public var profiles: [MouseKeyboardMappingProfile]

    public init(
        enabled: Bool,
        selectedProfileID: String,
        profiles: [MouseKeyboardMappingProfile]
    ) {
        self.enabled = enabled
        self.selectedProfileID = selectedProfileID
        self.profiles = profiles
    }

    public var selectedProfile: MouseKeyboardMappingProfile {
        profiles.first { $0.id == selectedProfileID } ?? Self.standardProfile
    }
}

public extension MouseKeyboardProfiles {
    static let defaultMouseSettings = MouseKeyboardMouseSettings(
        mapTo: .rightStick,
        sensitivityX: 100,
        sensitivityY: 100,
        deadzoneCounterweight: 20
    )

    static let standardProfile = MouseKeyboardMappingProfile(
        id: "standard",
        name: "Standard",
        bindings: [
            .nexus: ["Backquote"],
            .dpadUp: ["ArrowUp", "Digit1"],
            .dpadDown: ["ArrowDown", "Digit2"],
            .dpadLeft: ["ArrowLeft", "Digit3"],
            .dpadRight: ["ArrowRight", "Digit4"],
            .leftStickUp: ["KeyW"],
            .leftStickDown: ["KeyS"],
            .leftStickLeft: ["KeyA"],
            .leftStickRight: ["KeyD"],
            .rightStickUp: ["KeyU"],
            .rightStickDown: ["KeyJ"],
            .rightStickLeft: ["KeyH"],
            .rightStickRight: ["KeyK"],
            .buttonA: ["Space", "KeyE"],
            .buttonX: ["KeyR"],
            .buttonB: ["KeyC", "Backspace"],
            .buttonY: ["KeyV"],
            .menu: ["Enter"],
            .view: ["Tab"],
            .leftShoulder: ["KeyQ"],
            .rightShoulder: ["KeyF"],
            .rightTrigger: ["Mouse0"],
            .leftTrigger: ["Mouse2"],
            .leftThumbPress: ["KeyX"],
            .rightThumbPress: ["KeyZ"]
        ],
        mouse: defaultMouseSettings,
        isBuiltIn: true
    )

    static let shooterProfile = MouseKeyboardMappingProfile(
        id: "shooter",
        name: "Shooter",
        bindings: [
            .nexus: ["Backquote"],
            .dpadUp: ["ArrowUp"],
            .dpadDown: ["ArrowDown"],
            .dpadLeft: ["ArrowLeft"],
            .dpadRight: ["ArrowRight"],
            .leftStickUp: ["KeyW"],
            .leftStickDown: ["KeyS"],
            .leftStickLeft: ["KeyA"],
            .leftStickRight: ["KeyD"],
            .rightStickUp: ["KeyI"],
            .rightStickDown: ["KeyK"],
            .rightStickLeft: ["KeyJ"],
            .rightStickRight: ["KeyL"],
            .buttonA: ["Space", "KeyE"],
            .buttonX: ["KeyR"],
            .buttonB: ["ControlLeft", "Backspace"],
            .buttonY: ["KeyV"],
            .menu: ["Enter"],
            .view: ["Tab"],
            .leftShoulder: ["KeyC", "KeyG"],
            .rightShoulder: ["KeyQ"],
            .rightTrigger: ["Mouse0"],
            .leftTrigger: ["Mouse2"],
            .leftThumbPress: ["ShiftLeft"],
            .rightThumbPress: ["KeyF"]
        ],
        mouse: defaultMouseSettings,
        isBuiltIn: true
    )

    static let defaults = MouseKeyboardProfiles(
        enabled: true,
        selectedProfileID: standardProfile.id,
        profiles: [standardProfile, shooterProfile]
    )
}
