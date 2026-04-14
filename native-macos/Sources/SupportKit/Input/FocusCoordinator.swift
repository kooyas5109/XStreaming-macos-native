import Foundation

public enum FocusMoveDirection: Sendable {
    case previous
    case next
}

public struct FocusCoordinator: Sendable {
    public private(set) var focusedIndex: Int?
    public private(set) var focusableCount: Int

    public init(focusableCount: Int = 0, focusedIndex: Int? = nil) {
        self.focusableCount = max(0, focusableCount)
        if let focusedIndex, focusableCount > 0 {
            self.focusedIndex = min(max(0, focusedIndex), focusableCount - 1)
        } else {
            self.focusedIndex = nil
        }
    }

    public mutating func updateFocusableCount(_ count: Int) {
        focusableCount = max(0, count)

        guard focusableCount > 0 else {
            focusedIndex = nil
            return
        }

        if let focusedIndex {
            self.focusedIndex = min(focusedIndex, focusableCount - 1)
        } else {
            focusedIndex = 0
        }
    }

    @discardableResult
    public mutating func move(_ direction: FocusMoveDirection) -> Int? {
        guard focusableCount > 0 else {
            focusedIndex = nil
            return nil
        }

        let current = focusedIndex ?? 0

        switch direction {
        case .previous:
            focusedIndex = (current - 1 + focusableCount) % focusableCount
        case .next:
            focusedIndex = (current + 1) % focusableCount
        }

        return focusedIndex
    }

    public var canActivateFocusedElement: Bool {
        focusedIndex != nil
    }
}
