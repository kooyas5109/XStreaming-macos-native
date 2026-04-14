import Foundation
import SharedDomain
import Testing
@testable import StreamingFeature

@Test
@MainActor
func compatibilityEngineImplementsStreamingProtocol() throws {
    let engine: any StreamingEngineProtocol = WebViewStreamingEngine.preview()
    #expect(engine.capabilities.supportsVideo == true)
    #expect(engine.capabilities.supportsPointerInput == true)
}

@Test
@MainActor
func compatibilityEngineBuildsSessionURLFromConfiguration() async throws {
    let session = StreamingSession(
        id: "stream-1",
        targetID: "title-1",
        sessionPath: "/play/session-1",
        kind: .cloud,
        state: .readyToConnect
    )
    let engine = WebViewStreamingEngine(
        configuration: WebViewStreamingConfiguration(
            baseURL: URL(string: "https://stream.example.com")!
        ),
        bridgeScript: "window.nativeStreamingBridge = {};"
    )

    try await engine.prepare(session: session)

    #expect(engine.currentURL?.absoluteString == "https://stream.example.com/play/session-1")
    #expect(engine.currentSession?.id == "stream-1")
}

@Test
func compatibilityBridgeScriptExposesNativeHooks() throws {
    let script = try BridgeScriptLoader.load()

    #expect(script.contains("nativeStreamingBridge"))
    #expect(script.contains("requestFullscreen"))
    #expect(script.contains("ice-candidate"))
}
