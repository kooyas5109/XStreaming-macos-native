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
func keyboardMapperReturnsNilForUnknownKey() throws {
    let mapper = KeyboardMapper.default
    #expect(mapper.action(for: "Escape") == nil)
}
