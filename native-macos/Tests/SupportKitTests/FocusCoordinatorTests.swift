import Testing
@testable import SupportKit

@Test
func focusCoordinatorStartsAtFirstElementWhenCountAppears() {
    var coordinator = FocusCoordinator()
    coordinator.updateFocusableCount(3)

    #expect(coordinator.focusedIndex == 0)
}

@Test
func focusCoordinatorMovesForwardAndWraps() {
    var coordinator = FocusCoordinator(focusableCount: 3, focusedIndex: 2)
    let next = coordinator.move(.next)

    #expect(next == 0)
    #expect(coordinator.focusedIndex == 0)
}

@Test
func focusCoordinatorMovesBackwardAndWraps() {
    var coordinator = FocusCoordinator(focusableCount: 3, focusedIndex: 0)
    let previous = coordinator.move(.previous)

    #expect(previous == 2)
    #expect(coordinator.focusedIndex == 2)
}
