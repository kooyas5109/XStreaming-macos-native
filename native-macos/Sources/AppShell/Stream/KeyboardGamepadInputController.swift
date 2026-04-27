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
        let binding = WebInputCodeMapper.mouseButtonCode(for: event)
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
        WebInputCodeMapper.code(for: event)
    }
}
