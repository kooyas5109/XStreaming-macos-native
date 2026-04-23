import Testing
@testable import StreamingFeature

@Test
func keyboardGamepadStateTrackerMapsWasdToLeftStick() throws {
    var tracker = KeyboardGamepadStateTracker()

    let left = tracker.update(key: "a", isPressed: true)
    #expect(left?.leftThumbX == -1)
    #expect(left?.leftThumbY == 0)

    let right = tracker.update(key: "d", isPressed: true)
    #expect(right?.leftThumbX == 1)

    let leftAgain = tracker.update(key: "d", isPressed: false)
    #expect(leftAgain?.leftThumbX == -1)

    let neutral = tracker.update(key: "a", isPressed: false)
    #expect(neutral?.leftThumbX == 0)
}

@Test
func keyboardGamepadStateTrackerKeepsButtonsHeldUntilReleased() throws {
    var tracker = KeyboardGamepadStateTracker()

    let buttonA = tracker.update(key: "Enter", isPressed: true)
    #expect(buttonA?.buttons.contains(.buttonA) == true)

    let trigger = tracker.update(key: "1", isPressed: true)
    #expect(trigger?.buttons.contains(.buttonA) == true)
    #expect(trigger?.leftTrigger == 1)

    let releasedA = tracker.update(key: "Enter", isPressed: false)
    #expect(releasedA?.buttons.contains(.buttonA) == false)
    #expect(releasedA?.leftTrigger == 1)

    let neutral = tracker.reset()
    #expect(neutral == StreamingGamepadState())
}

@Test
func keyboardGamepadStateTrackerIgnoresUnmappedAndRepeatedKeys() throws {
    var tracker = KeyboardGamepadStateTracker()

    #expect(tracker.update(key: "Escape", isPressed: true) == nil)
    #expect(tracker.update(key: "w", isPressed: true)?.leftThumbY == 1)
    #expect(tracker.update(key: "w", isPressed: true) == nil)
    #expect(tracker.update(key: "w", isPressed: false)?.leftThumbY == 0)
}
