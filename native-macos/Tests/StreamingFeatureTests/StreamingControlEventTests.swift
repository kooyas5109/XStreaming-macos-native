import Foundation
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

@Test
func controlPayloadEncoderBuildsStableButtonPayloads() throws {
    let encoder = StreamingControlPayloadEncoder()
    let payload = encoder.payload(for: .button(.nexus, .began))
    let data = try encoder.encode(payload)
    let decoded = try JSONDecoder().decode(StreamingControlPayload.self, from: data)

    #expect(payload == StreamingControlPayload(
        type: "button",
        button: "Nexus",
        phase: "began"
    ))
    #expect(decoded == payload)
}

@Test
func controlPayloadEncoderBuildsStableDataChannelFrames() throws {
    let encoder = StreamingControlPayloadEncoder()
    let data = try encoder.encode(event: .microphone(active: true))
    let decoded = try JSONDecoder().decode(StreamingControlPayload.self, from: data)

    #expect(decoded == StreamingControlPayload(
        type: "microphone",
        active: true
    ))
}

@Test
func controlPayloadEncoderBuildsTextAndMicrophonePayloads() {
    let encoder = StreamingControlPayloadEncoder()

    #expect(encoder.payload(for: .text("hello xbox")) == StreamingControlPayload(
        type: "text",
        text: "hello xbox"
    ))
    #expect(encoder.payload(for: .microphone(active: true)) == StreamingControlPayload(
        type: "microphone",
        active: true
    ))
}
