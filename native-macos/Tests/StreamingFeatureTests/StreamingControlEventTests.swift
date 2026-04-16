import SupportKit
import Testing
@testable import StreamingFeature

@Test
func inputTranslatorMapsDigitalActionsToStreamingButtons() {
    let translator = StreamingInputTranslator()

    #expect(translator.button(for: .buttonA) == .buttonA)
    #expect(translator.button(for: .dpadUp) == .dpadUp)
    #expect(translator.button(for: .nexus) == .nexus)
    #expect(translator.events(for: .menu, phase: .began) == [
        .button(.menu, .began)
    ])
}

@Test
func inputTranslatorLeavesAnalogAxesForFutureStickPackets() {
    let translator = StreamingInputTranslator()

    #expect(translator.button(for: .leftThumbXAxisPlus) == nil)
    #expect(translator.events(for: .rightThumbYAxisMinus, phase: .ended) == [])
}
