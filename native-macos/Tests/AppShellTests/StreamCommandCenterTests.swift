import SharedDomain
import Testing
@testable import AppShell

@MainActor
@Test
func streamCommandCenterDispatchesRegisteredActions() {
    let commandCenter = StreamCommandCenter()
    var didTogglePerformance = false
    var didSendText = false

    commandCenter.register(
        context: StreamCommandCenter.Context(
            route: .streamConsole(id: "console-1"),
            language: .english,
            canSendText: true,
            canPowerOff: true,
            isMicrophoneOpen: false
        ),
        actions: StreamCommandCenter.Actions(
            togglePerformance: { didTogglePerformance = true },
            toggleDisplay: {},
            toggleAudio: {},
            toggleMicrophone: {},
            toggleFullscreen: {},
            sendText: { didSendText = true },
            pressNexus: {},
            longPressNexus: {},
            disconnect: {},
            disconnectAndPowerOff: {}
        )
    )

    commandCenter.performTogglePerformance()
    commandCenter.performSendText()

    #expect(didTogglePerformance)
    #expect(didSendText)
    #expect(commandCenter.context?.canPowerOff == true)
}

@MainActor
@Test
func streamCommandCenterUnregistersMatchingRoute() {
    let commandCenter = StreamCommandCenter()

    commandCenter.register(
        context: StreamCommandCenter.Context(
            route: .streamCloud(id: "title-1"),
            language: .simplifiedChinese,
            canSendText: false,
            canPowerOff: false,
            isMicrophoneOpen: true
        ),
        actions: StreamCommandCenter.Actions(
            togglePerformance: {},
            toggleDisplay: {},
            toggleAudio: {},
            toggleMicrophone: {},
            toggleFullscreen: {},
            sendText: {},
            pressNexus: {},
            longPressNexus: {},
            disconnect: {},
            disconnectAndPowerOff: {}
        )
    )

    commandCenter.unregister(for: .streamCloud(id: "title-1"))

    #expect(commandCenter.context == nil)
}
