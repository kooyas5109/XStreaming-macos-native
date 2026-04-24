import AppKit
import Foundation
import StreamingFeature
import SupportKit

@MainActor
final class KeyboardGamepadInputController: ObservableObject {
    struct Result {
        let handled: Bool
        let state: StreamingGamepadState?
    }

    private var tracker = KeyboardGamepadStateTracker()
    private let logger = AppLogger(category: "WebRTC")

    func handle(_ event: NSEvent) -> Result {
        guard event.type == .keyDown || event.type == .keyUp else {
            return Result(handled: false, state: nil)
        }

        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard event.modifierFlags.intersection(blockedModifiers).isEmpty else {
            logger.info("Keyboard gamepad input ignored due to blocked modifiers: keyCode=\(event.keyCode)")
            return Result(handled: false, state: nil)
        }

        guard let key = keyIdentifier(for: event) else {
            logger.info("Keyboard gamepad input ignored because key is unmapped: keyCode=\(event.keyCode)")
            return Result(handled: false, state: nil)
        }

        if event.type == .keyDown && event.isARepeat {
            return Result(handled: tracker.currentState() != StreamingGamepadState(), state: nil)
        }

        let state = tracker.update(key: key, isPressed: event.type == .keyDown)
        if state != nil {
            logger.info("Keyboard gamepad input captured: key=\(key), pressed=\(event.type == .keyDown)")
        }
        return Result(handled: state != nil, state: state)
    }

    func reset() -> StreamingGamepadState? {
        tracker.reset()
    }

    private func keyIdentifier(for event: NSEvent) -> String? {
        switch event.keyCode {
        case 36, 76:
            return "Enter"
        case 51:
            return "Backspace"
        case 123:
            return "ArrowLeft"
        case 124:
            return "ArrowRight"
        case 125:
            return "ArrowDown"
        case 126:
            return "ArrowUp"
        default:
            return event.charactersIgnoringModifiers?.lowercased()
        }
    }
}
