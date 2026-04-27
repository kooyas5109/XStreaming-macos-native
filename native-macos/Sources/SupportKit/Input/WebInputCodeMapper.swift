import AppKit

public enum WebInputCodeMapper {
    private static let keyCodes: [UInt16: String] = [
        0: "KeyA", 1: "KeyS", 2: "KeyD", 3: "KeyF", 4: "KeyH", 5: "KeyG",
        6: "KeyZ", 7: "KeyX", 8: "KeyC", 9: "KeyV", 11: "KeyB", 12: "KeyQ",
        13: "KeyW", 14: "KeyE", 15: "KeyR", 16: "KeyY", 17: "KeyT", 18: "Digit1",
        19: "Digit2", 20: "Digit3", 21: "Digit4", 22: "Digit6", 23: "Digit5",
        24: "Equal", 25: "Digit9", 26: "Digit7", 27: "Minus", 28: "Digit8",
        29: "Digit0", 30: "BracketRight", 31: "KeyO", 32: "KeyU", 33: "BracketLeft",
        34: "KeyI", 35: "KeyP", 36: "Enter", 37: "KeyL", 38: "KeyJ", 39: "Quote",
        40: "KeyK", 41: "Semicolon", 42: "Backslash", 43: "Comma", 44: "Slash",
        45: "KeyN", 46: "KeyM", 47: "Period", 48: "Tab", 49: "Space", 50: "Backquote",
        51: "Backspace", 53: "Escape", 55: "MetaLeft", 56: "ShiftLeft",
        57: "CapsLock", 58: "AltLeft", 59: "ControlLeft", 60: "ShiftRight",
        61: "AltRight", 62: "ControlRight", 63: "Fn", 64: "F17", 65: "NumpadDecimal",
        67: "NumpadMultiply", 69: "NumpadAdd", 71: "NumLock", 75: "NumpadDivide",
        76: "Enter", 78: "NumpadSubtract", 81: "NumpadEqual", 82: "Numpad0",
        83: "Numpad1", 84: "Numpad2", 85: "Numpad3", 86: "Numpad4", 87: "Numpad5",
        88: "Numpad6", 89: "Numpad7", 91: "Numpad8", 92: "Numpad9", 96: "F5",
        97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15",
        114: "Insert", 115: "Home", 116: "PageUp", 117: "Delete", 118: "F4",
        119: "End", 120: "F2", 121: "PageDown", 122: "F1", 123: "ArrowLeft",
        124: "ArrowRight", 125: "ArrowDown", 126: "ArrowUp"
    ]

    private static let displayNames: [String: String] = [
        "Backquote": "`", "Minus": "-", "Equal": "=", "BracketLeft": "[", "BracketRight": "]",
        "Semicolon": ";", "Quote": "'", "Backslash": "\\", "Comma": ",", "Period": ".",
        "Slash": "/", "Backspace": "Backspace", "Escape": "Esc", "Enter": "Enter",
        "Tab": "Tab", "Space": "Space", "ShiftLeft": "Left Shift", "ShiftRight": "Right Shift",
        "ControlLeft": "Left Ctrl", "ControlRight": "Right Ctrl", "AltLeft": "Left Alt",
        "AltRight": "Right Alt", "MetaLeft": "Command", "ArrowLeft": "Left Arrow",
        "ArrowRight": "Right Arrow", "ArrowUp": "Up Arrow", "ArrowDown": "Down Arrow",
        "Mouse0": "Mouse Left", "Mouse1": "Mouse Middle", "Mouse2": "Mouse Right",
        "ScrollUp": "Wheel Up", "ScrollDown": "Wheel Down", "ScrollLeft": "Wheel Left",
        "ScrollRight": "Wheel Right"
    ]

    public static func code(for event: NSEvent) -> String? {
        keyCodes[event.keyCode]
    }

    public static func mouseButtonCode(for event: NSEvent) -> String {
        "Mouse\(event.buttonNumber)"
    }

    public static func wheelCode(vertical: Double, horizontal: Double) -> String? {
        if vertical < 0 { return "ScrollUp" }
        if vertical > 0 { return "ScrollDown" }
        if horizontal < 0 { return "ScrollLeft" }
        if horizontal > 0 { return "ScrollRight" }
        return nil
    }

    public static func displayName(for code: String) -> String {
        if let displayName = displayNames[code] {
            return displayName
        }
        if code.hasPrefix("Key"), code.count == 4 {
            return String(code.suffix(1))
        }
        if code.hasPrefix("Digit"), let digit = Int(code.dropFirst(5)) {
            return String(digit)
        }
        return code
    }
}
