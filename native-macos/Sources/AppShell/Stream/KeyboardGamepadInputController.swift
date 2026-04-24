import AppKit
import Foundation
import SharedDomain
import StreamingFeature
import SupportKit

@MainActor
final class KeyboardGamepadInputController: ObservableObject {
    struct Result {
        let handled: Bool
        let state: StreamingGamepadState?
    }

    private var tracker = MouseKeyboardGamepadStateTracker()
    private var enabled = true
    private var mouseStopTask: Task<Void, Never>?
    private var wheelStopTask: Task<Void, Never>?
    private var previousWheelDelta: (vertical: Double, horizontal: Double)?
    private var stateSink: ((StreamingGamepadState) -> Void)?
    private let logger = AppLogger(category: "WebRTC")

    func setStateSink(_ stateSink: @escaping (StreamingGamepadState) -> Void) {
        self.stateSink = stateSink
    }

    func configure(profiles: MouseKeyboardProfiles) {
        enabled = profiles.enabled
        tracker.updateProfile(profiles.selectedProfile)
        logger.info("Mouse keyboard gamepad profile configured: enabled=\(profiles.enabled), profile=\(profiles.selectedProfile.id)")
    }

    func handle(_ event: NSEvent) -> Result {
        guard enabled else {
            return Result(handled: false, state: nil)
        }
        guard event.type == .keyDown || event.type == .keyUp else {
            return Result(handled: false, state: nil)
        }

        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard event.modifierFlags.intersection(blockedModifiers).isEmpty else {
            logger.info("Keyboard gamepad input ignored due to blocked modifiers: keyCode=\(event.keyCode)")
            return Result(handled: false, state: nil)
        }

        guard let key = webKeyCode(for: event) else {
            logger.info("Keyboard gamepad input ignored because key is unmapped: keyCode=\(event.keyCode)")
            return Result(handled: false, state: nil)
        }

        if event.type == .keyDown && event.isARepeat {
            return Result(handled: tracker.currentState() != StreamingGamepadState(), state: nil)
        }

        let state = tracker.update(binding: key, isPressed: event.type == .keyDown)
        if state != nil {
            logger.info("Keyboard gamepad input captured: key=\(key), pressed=\(event.type == .keyDown)")
        }
        return Result(handled: state != nil, state: state)
    }

    func handleMouseButton(_ event: NSEvent, pressed: Bool) -> Result {
        guard enabled else {
            return Result(handled: false, state: nil)
        }
        let binding = "Mouse\(event.buttonNumber)"
        let state = tracker.update(binding: binding, isPressed: pressed)
        if state != nil {
            logger.info("Mouse gamepad input captured: button=\(binding), pressed=\(pressed)")
        }
        return Result(handled: state != nil, state: state)
    }

    func handleMouseMove(_ event: NSEvent) -> Result {
        guard enabled else {
            return Result(handled: false, state: nil)
        }
        let state = tracker.updateMouseMovement(deltaX: event.deltaX, deltaY: event.deltaY)
        guard let state else {
            return Result(handled: false, state: nil)
        }
        mouseStopTask?.cancel()
        mouseStopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard Task.isCancelled == false else { return }
            Task { @MainActor in
                _ = self?.handleMouseStopped()
            }
        }
        logger.info("Mouse movement mapped to gamepad stick: dx=\(event.deltaX), dy=\(event.deltaY)")
        return Result(handled: true, state: state)
    }

    func handleMouseWheel(_ event: NSEvent) -> Result {
        guard enabled else {
            return Result(handled: false, state: nil)
        }
        let delta = (vertical: Double(event.scrollingDeltaY), horizontal: Double(event.scrollingDeltaX))
        let state = tracker.updateWheel(vertical: delta.vertical, horizontal: delta.horizontal, isPressed: true)
        guard let state else {
            return Result(handled: false, state: nil)
        }
        previousWheelDelta = delta
        wheelStopTask?.cancel()
        wheelStopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000)
            guard Task.isCancelled == false else { return }
            Task { @MainActor in
                _ = self?.handleWheelStopped()
            }
        }
        logger.info("Mouse wheel mapped to gamepad input: vertical=\(delta.vertical), horizontal=\(delta.horizontal)")
        return Result(handled: true, state: state)
    }

    func reset() -> StreamingGamepadState? {
        mouseStopTask?.cancel()
        wheelStopTask?.cancel()
        return tracker.reset()
    }

    private func handleMouseStopped() -> StreamingGamepadState? {
        let state = tracker.stopMouseMovement()
        if let state {
            stateSink?(state)
        }
        return state
    }

    private func handleWheelStopped() -> StreamingGamepadState? {
        guard let previousWheelDelta else {
            return nil
        }
        self.previousWheelDelta = nil
        let state = tracker.updateWheel(
            vertical: previousWheelDelta.vertical,
            horizontal: previousWheelDelta.horizontal,
            isPressed: false
        )
        if let state {
            stateSink?(state)
        }
        return state
    }

    private func webKeyCode(for event: NSEvent) -> String? {
        switch event.keyCode {
        case 0: return "KeyA"
        case 1: return "KeyS"
        case 2: return "KeyD"
        case 3: return "KeyF"
        case 4: return "KeyH"
        case 5: return "KeyG"
        case 6: return "KeyZ"
        case 7: return "KeyX"
        case 8: return "KeyC"
        case 9: return "KeyV"
        case 11: return "KeyB"
        case 12: return "KeyQ"
        case 13: return "KeyW"
        case 14: return "KeyE"
        case 15: return "KeyR"
        case 16: return "KeyY"
        case 17: return "KeyT"
        case 31: return "KeyO"
        case 32: return "KeyU"
        case 34: return "KeyI"
        case 35: return "KeyP"
        case 37: return "KeyL"
        case 38: return "KeyJ"
        case 40: return "KeyK"
        case 45: return "KeyN"
        case 46: return "KeyM"
        case 18: return "Digit1"
        case 19: return "Digit2"
        case 20: return "Digit3"
        case 21: return "Digit4"
        case 23: return "Digit5"
        case 22: return "Digit6"
        case 26: return "Digit7"
        case 28: return "Digit8"
        case 25: return "Digit9"
        case 29: return "Digit0"
        case 36, 76:
            return "Enter"
        case 51:
            return "Backspace"
        case 48:
            return "Tab"
        case 49:
            return "Space"
        case 50:
            return "Backquote"
        case 53:
            return "Escape"
        case 56:
            return "ShiftLeft"
        case 59:
            return "ControlLeft"
        case 58:
            return "AltLeft"
        case 123:
            return "ArrowLeft"
        case 124:
            return "ArrowRight"
        case 125:
            return "ArrowDown"
        case 126:
            return "ArrowUp"
        default:
            return nil
        }
    }
}
