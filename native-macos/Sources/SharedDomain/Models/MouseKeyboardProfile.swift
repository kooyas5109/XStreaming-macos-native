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
    static let bindingSlotsPerControl = 2
    static let controlOrder: [MouseKeyboardGamepadControl] = [
        .nexus,
        .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
        .buttonA, .buttonB, .buttonX, .buttonY,
        .leftShoulder, .rightShoulder, .leftTrigger, .rightTrigger,
        .view, .menu,
        .leftThumbPress, .leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight,
        .rightThumbPress, .rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight
    ]
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

    static func blankCustomProfile(name: String = "Custom") -> MouseKeyboardMappingProfile {
        MouseKeyboardMappingProfile(
            id: UUID().uuidString.lowercased(),
            name: name,
            bindings: [:],
            mouse: defaultMouseSettings
        )
    }

    func profile(withID id: String) -> MouseKeyboardMappingProfile? {
        profiles.first { $0.id == id }
    }

    func binding(for control: MouseKeyboardGamepadControl, slot: Int, in profileID: String? = nil) -> String? {
        let resolvedProfile = profile(withID: profileID ?? selectedProfileID) ?? selectedProfile
        guard slot >= 0 else {
            return nil
        }
        let bindings = resolvedProfile.bindings[control] ?? []
        guard slot < bindings.count else {
            return nil
        }
        return bindings[slot]
    }

    func selectingProfile(_ profileID: String) -> MouseKeyboardProfiles {
        MouseKeyboardProfiles(
            enabled: enabled,
            selectedProfileID: profileID,
            profiles: profiles
        )
    }

    func upserting(_ profile: MouseKeyboardMappingProfile, selecting selectProfile: Bool = true) -> MouseKeyboardProfiles {
        var updatedProfiles = profiles
        if let index = updatedProfiles.firstIndex(where: { $0.id == profile.id }) {
            updatedProfiles[index] = profile
        } else {
            updatedProfiles.append(profile)
        }

        return MouseKeyboardProfiles(
            enabled: enabled,
            selectedProfileID: selectProfile ? profile.id : selectedProfileID,
            profiles: updatedProfiles
        )
    }

    func deletingProfile(_ profileID: String) -> MouseKeyboardProfiles {
        let updatedProfiles = profiles.filter { $0.id != profileID }
        let selectedID = updatedProfiles.contains(where: { $0.id == selectedProfileID })
        ? selectedProfileID
        : (updatedProfiles.first?.id ?? Self.standardProfile.id)

        return MouseKeyboardProfiles(
            enabled: enabled,
            selectedProfileID: selectedID,
            profiles: updatedProfiles
        )
    }
}
