import Foundation
import SupportKit

public struct KeyboardGamepadStateTracker: Sendable {
    private let mapper: KeyboardMapper
    private let translator: StreamingInputTranslator
    private var pressedKeys: [String: GameInputAction] = [:]
    private var orderedKeys: [String] = []

    public init(
        mapper: KeyboardMapper = .default,
        translator: StreamingInputTranslator = StreamingInputTranslator()
    ) {
        self.mapper = mapper
        self.translator = translator
    }

    public mutating func update(key: String, isPressed: Bool) -> StreamingGamepadState? {
        guard let action = mapper.action(for: key) else {
            return nil
        }

        if isPressed {
            guard pressedKeys[key] == nil else {
                return nil
            }
            pressedKeys[key] = action
            orderedKeys.append(key)
        } else {
            guard pressedKeys.removeValue(forKey: key) != nil else {
                return nil
            }
            orderedKeys.removeAll { $0 == key }
        }

        return currentState()
    }

    public mutating func reset() -> StreamingGamepadState? {
        guard pressedKeys.isEmpty == false else {
            return nil
        }
        pressedKeys.removeAll()
        orderedKeys.removeAll()
        return currentState()
    }

    public func currentState() -> StreamingGamepadState {
        let actions = Set(pressedKeys.values)
        var state = StreamingGamepadState()

        for action in actions {
            switch action {
            case .leftTrigger:
                state.leftTrigger = 1
            case .rightTrigger:
                state.rightTrigger = 1
            default:
                if let button = translator.button(for: action) {
                    state.buttons.insert(button)
                }
            }
        }

        state.leftThumbX = axisValue(negative: .leftThumbXAxisMinus, positive: .leftThumbXAxisPlus)
        state.leftThumbY = axisValue(negative: .leftThumbYAxisMinus, positive: .leftThumbYAxisPlus)
        state.rightThumbX = axisValue(negative: .rightThumbXAxisMinus, positive: .rightThumbXAxisPlus)
        state.rightThumbY = axisValue(negative: .rightThumbYAxisMinus, positive: .rightThumbYAxisPlus)
        return state
    }

    private func axisValue(negative: GameInputAction, positive: GameInputAction) -> Double {
        for key in orderedKeys.reversed() {
            guard let action = pressedKeys[key] else {
                continue
            }
            if action == positive {
                return 1
            }
            if action == negative {
                return -1
            }
        }
        return 0
    }
}
