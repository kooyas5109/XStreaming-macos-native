import Foundation
import Testing
@testable import StreamingFeature

@Test
func controlChannelEncoderBuildsAuthorizationRequest() throws {
    let data = try StreamingControlChannelMessageEncoder().authorizationRequest()
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

    #expect(object["message"] == "authorizationRequest")
    #expect(object["accessKey"] == "4BDB3609-C1F1-4195-9B37-FEFF45DA8B8E")
}

@Test
func controlChannelEncoderBuildsGamepadChangedMessage() throws {
    let data = try StreamingControlChannelMessageEncoder().gamepadChanged(index: 1, wasAdded: true)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["message"] as? String == "gamepadChanged")
    #expect(object["gamepadIndex"] as? Int == 1)
    #expect(object["wasAdded"] as? Bool == true)
}

@Test
func controlChannelEncoderBuildsKeyframeRequest() throws {
    let data = try StreamingControlChannelMessageEncoder().videoKeyframeRequested()
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["message"] as? String == "videoKeyframeRequested")
    #expect(object["ifrRequested"] as? Bool == true)
}
