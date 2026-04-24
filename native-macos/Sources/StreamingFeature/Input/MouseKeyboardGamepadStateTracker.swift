import Foundation
import SharedDomain

public struct MouseKeyboardGamepadStateTracker: Sendable {
    private static let panningSensitivity = 0.001
    private static let deadzoneSensitivity = 0.01
    private static let maximumStickRange = 1.1

    private var profile: MouseKeyboardMappingProfile
    private var bindingToControl: [String: MouseKeyboardGamepadControl]
    private var pressedBindings: [String: MouseKeyboardGamepadControl] = [:]
    private var orderedBindings: [String] = []
    private var mouseStickTarget: MouseKeyboardMouseTarget
    private var mouseStickX = 0.0
    private var mouseStickY = 0.0
    private var previousWheelBinding: String?

    public init(profile: MouseKeyboardMappingProfile = MouseKeyboardProfiles.standardProfile) {
        self.profile = profile
        self.bindingToControl = Self.convertBindings(profile.bindings)
        self.mouseStickTarget = profile.mouse.mapTo
    }

    public mutating func updateProfile(_ profile: MouseKeyboardMappingProfile) {
        self.profile = profile
        self.bindingToControl = Self.convertBindings(profile.bindings)
        self.mouseStickTarget = profile.mouse.mapTo
        pressedBindings.removeAll()
        orderedBindings.removeAll()
        mouseStickX = 0
        mouseStickY = 0
        previousWheelBinding = nil
    }

    public mutating func update(binding: String, isPressed: Bool) -> StreamingGamepadState? {
        guard let control = bindingToControl[binding] else {
            return nil
        }

        if isPressed {
            guard pressedBindings[binding] == nil else {
                return nil
            }
            pressedBindings[binding] = control
            orderedBindings.append(binding)
        } else {
            guard pressedBindings.removeValue(forKey: binding) != nil else {
                return nil
            }
            orderedBindings.removeAll { $0 == binding }
        }

        return currentState()
    }

    public mutating func updateMouseMovement(deltaX: Double, deltaY: Double) -> StreamingGamepadState? {
        guard profile.mouse.mapTo != .off else {
            return nil
        }

        let deadzoneCounterweight = profile.mouse.deadzoneCounterweight * Self.deadzoneSensitivity
        var x = deltaX * profile.mouse.sensitivityX * Self.panningSensitivity
        var y = deltaY * profile.mouse.sensitivityY * Self.panningSensitivity

        let length = sqrt((x * x) + (y * y))
        if length != 0, length < deadzoneCounterweight {
            x *= deadzoneCounterweight / length
            y *= deadzoneCounterweight / length
        } else if length > Self.maximumStickRange {
            x *= Self.maximumStickRange / length
            y *= Self.maximumStickRange / length
        }

        mouseStickTarget = profile.mouse.mapTo
        mouseStickX = x
        mouseStickY = y
        return currentState()
    }

    public mutating func stopMouseMovement() -> StreamingGamepadState? {
        guard mouseStickX != 0 || mouseStickY != 0 else {
            return nil
        }
        mouseStickX = 0
        mouseStickY = 0
        return currentState()
    }

    public mutating func updateWheel(vertical: Double, horizontal: Double, isPressed: Bool) -> StreamingGamepadState? {
        let binding: String?
        if vertical < 0 {
            binding = "ScrollUp"
        } else if vertical > 0 {
            binding = "ScrollDown"
        } else if horizontal < 0 {
            binding = "ScrollLeft"
        } else if horizontal > 0 {
            binding = "ScrollRight"
        } else {
            binding = nil
        }

        guard let binding else {
            return nil
        }

        if isPressed {
            previousWheelBinding = binding
        } else if previousWheelBinding != binding {
            return nil
        } else {
            previousWheelBinding = nil
        }

        return update(binding: binding, isPressed: isPressed)
    }

    public mutating func reset() -> StreamingGamepadState? {
        guard pressedBindings.isEmpty == false || mouseStickX != 0 || mouseStickY != 0 else {
            return nil
        }
        pressedBindings.removeAll()
        orderedBindings.removeAll()
        mouseStickX = 0
        mouseStickY = 0
        previousWheelBinding = nil
        return currentState()
    }

    public func currentState() -> StreamingGamepadState {
        var state = StreamingGamepadState()
        let controls = Set(pressedBindings.values)

        for control in controls {
            switch control {
            case .buttonA:
                state.buttons.insert(.buttonA)
            case .buttonB:
                state.buttons.insert(.buttonB)
            case .buttonX:
                state.buttons.insert(.buttonX)
            case .buttonY:
                state.buttons.insert(.buttonY)
            case .leftShoulder:
                state.buttons.insert(.leftShoulder)
            case .rightShoulder:
                state.buttons.insert(.rightShoulder)
            case .leftTrigger:
                state.leftTrigger = 1
            case .rightTrigger:
                state.rightTrigger = 1
            case .view:
                state.buttons.insert(.view)
            case .menu:
                state.buttons.insert(.menu)
            case .leftThumbPress:
                state.buttons.insert(.leftThumbPress)
            case .rightThumbPress:
                state.buttons.insert(.rightThumbPress)
            case .dpadUp:
                state.buttons.insert(.dpadUp)
            case .dpadDown:
                state.buttons.insert(.dpadDown)
            case .dpadLeft:
                state.buttons.insert(.dpadLeft)
            case .dpadRight:
                state.buttons.insert(.dpadRight)
            case .nexus:
                state.buttons.insert(.nexus)
            case .share:
                break
            case .leftStickUp,
                 .leftStickDown,
                 .leftStickLeft,
                 .leftStickRight,
                 .rightStickUp,
                 .rightStickDown,
                 .rightStickLeft,
                 .rightStickRight:
                break
            }
        }

        state.leftThumbX = axisValue(negative: .leftStickLeft, positive: .leftStickRight)
        state.leftThumbY = axisValue(negative: .leftStickDown, positive: .leftStickUp)
        state.rightThumbX = axisValue(negative: .rightStickLeft, positive: .rightStickRight)
        state.rightThumbY = axisValue(negative: .rightStickDown, positive: .rightStickUp)

        if mouseStickX != 0 || mouseStickY != 0 {
            switch mouseStickTarget {
            case .leftStick:
                state.leftThumbX = mouseStickX
                state.leftThumbY = -mouseStickY
            case .rightStick:
                state.rightThumbX = mouseStickX
                state.rightThumbY = -mouseStickY
            case .off:
                break
            }
        }

        return state
    }

    private static func convertBindings(_ bindings: [MouseKeyboardGamepadControl: [String]]) -> [String: MouseKeyboardGamepadControl] {
        var converted: [String: MouseKeyboardGamepadControl] = [:]
        for (control, keys) in bindings {
            for key in keys {
                converted[key] = control
            }
        }
        return converted
    }

    private func axisValue(
        negative: MouseKeyboardGamepadControl,
        positive: MouseKeyboardGamepadControl
    ) -> Double {
        for binding in orderedBindings.reversed() {
            guard let control = pressedBindings[binding] else {
                continue
            }
            if control == positive {
                return 1
            }
            if control == negative {
                return -1
            }
        }
        return 0
    }
}
