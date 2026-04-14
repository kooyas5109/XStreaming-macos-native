import SharedDomain
import SwiftUI

public struct StreamCommands: Commands {
    @ObservedObject private var commandCenter: StreamCommandCenter

    public init(commandCenter: StreamCommandCenter) {
        self.commandCenter = commandCenter
    }

    public var body: some Commands {
        CommandMenu(menuTitle) {
            Button(strings.togglePerformanceAction) {
                commandCenter.performTogglePerformance()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(commandCenter.context == nil)

            Button(strings.displaySettingsAction) {
                commandCenter.performToggleDisplay()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .disabled(commandCenter.context == nil)

            Button(strings.audioSettingsAction) {
                commandCenter.performToggleAudio()
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(commandCenter.context == nil)

            Button(commandCenter.context?.isMicrophoneOpen == true ? strings.closeMicAction : strings.openMicAction) {
                commandCenter.performToggleMicrophone()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(commandCenter.context == nil)

            Divider()

            Button(strings.sendTextAction) {
                commandCenter.performSendText()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(commandCenter.context?.canSendText != true)

            Button(strings.pressNexusAction) {
                commandCenter.performPressNexus()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(commandCenter.context == nil)

            Button(strings.longPressNexusAction) {
                commandCenter.performLongPressNexus()
            }
            .keyboardShortcut("n", modifiers: [.command, .option, .shift])
            .disabled(commandCenter.context?.canSendText != true)

            Divider()

            Button(strings.fullscreenAction) {
                commandCenter.performToggleFullscreen()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(commandCenter.context == nil)

            Button(strings.disconnectAndPowerOffAction) {
                commandCenter.performDisconnectAndPowerOff()
            }
            .disabled(commandCenter.context?.canPowerOff != true)

            Button(strings.disconnectAction) {
                commandCenter.performDisconnect()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .disabled(commandCenter.context == nil)
        }
    }

    private var strings: ShellStrings {
        ShellStrings(language: commandCenter.context?.language ?? .english)
    }

    private var menuTitle: String {
        commandCenter.context?.language == AppLanguage.simplifiedChinese ? "串流" : "Stream"
    }
}
