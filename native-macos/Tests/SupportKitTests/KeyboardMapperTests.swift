import Testing
@testable import SupportKit

@Test
func keyboardMapperReturnsAForEnter() throws {
    let mapper = KeyboardMapper.default
    #expect(mapper.action(for: "Enter") == .buttonA)
}

@Test
func keyboardMapperReturnsDPadUpForArrowUp() throws {
    let mapper = KeyboardMapper.default
    #expect(mapper.action(for: "ArrowUp") == .dpadUp)
}

@Test
func keyboardMapperUsesWasdForLeftStick() throws {
    let mapper = KeyboardMapper.default
    #expect(mapper.action(for: "a") == .leftThumbXAxisMinus)
    #expect(mapper.action(for: "d") == .leftThumbXAxisPlus)
    #expect(mapper.action(for: "w") == .leftThumbYAxisPlus)
    #expect(mapper.action(for: "s") == .leftThumbYAxisMinus)
}

@Test
func keyboardMapperReturnsNilForUnknownKey() throws {
    let mapper = KeyboardMapper.default
    #expect(mapper.action(for: "Escape") == nil)
}
