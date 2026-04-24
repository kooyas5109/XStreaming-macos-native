import SharedDomain
import StreamingFeature
import Testing

@Test
func mouseKeyboardTrackerMapsStandardKeyboardBindings() throws {
    var tracker = MouseKeyboardGamepadStateTracker(profile: MouseKeyboardProfiles.standardProfile)

    let forwardState = tracker.update(binding: "KeyW", isPressed: true)
    let forward = try #require(forwardState)
    #expect(forward.leftThumbY == 1)

    let leftState = tracker.update(binding: "KeyA", isPressed: true)
    let left = try #require(leftState)
    #expect(left.leftThumbX == -1)

    let neutralYState = tracker.update(binding: "KeyW", isPressed: false)
    let neutralY = try #require(neutralYState)
    #expect(neutralY.leftThumbY == 0)
    #expect(neutralY.leftThumbX == -1)
}

@Test
func mouseKeyboardTrackerMapsMouseButtonsToTriggers() throws {
    var tracker = MouseKeyboardGamepadStateTracker(profile: MouseKeyboardProfiles.standardProfile)

    let fireState = tracker.update(binding: "Mouse0", isPressed: true)
    let fire = try #require(fireState)
    #expect(fire.rightTrigger == 1)

    let releasedState = tracker.update(binding: "Mouse0", isPressed: false)
    let released = try #require(releasedState)
    #expect(released.rightTrigger == 0)
}

@Test
func mouseKeyboardTrackerMapsMouseMovementToRightStick() throws {
    var tracker = MouseKeyboardGamepadStateTracker(profile: MouseKeyboardProfiles.standardProfile)

    let movedState = tracker.updateMouseMovement(deltaX: 8, deltaY: -4)
    let moved = try #require(movedState)
    #expect(moved.rightThumbX > 0)
    #expect(moved.rightThumbY > 0)

    let stoppedState = tracker.stopMouseMovement()
    let stopped = try #require(stoppedState)
    #expect(stopped.rightThumbX == 0)
    #expect(stopped.rightThumbY == 0)
}

@Test
func mouseKeyboardTrackerRestoresKeyboardStickAfterMouseStops() throws {
    var tracker = MouseKeyboardGamepadStateTracker(profile: MouseKeyboardProfiles.standardProfile)

    let keyboardState = tracker.update(binding: "KeyH", isPressed: true)
    let keyboard = try #require(keyboardState)
    #expect(keyboard.rightThumbX == -1)

    let movedState = tracker.updateMouseMovement(deltaX: 8, deltaY: 0)
    let moved = try #require(movedState)
    #expect(moved.rightThumbX > 0)

    let stoppedState = tracker.stopMouseMovement()
    let stopped = try #require(stoppedState)
    #expect(stopped.rightThumbX == -1)
}
