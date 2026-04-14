import Foundation
import SharedDomain

@MainActor
public final class StreamCommandCenter: ObservableObject {
    public struct Context: Sendable {
        public let route: AppRouter.Route
        public let language: AppLanguage
        public let canSendText: Bool
        public let canPowerOff: Bool
        public let isMicrophoneOpen: Bool

        public init(
            route: AppRouter.Route,
            language: AppLanguage,
            canSendText: Bool,
            canPowerOff: Bool,
            isMicrophoneOpen: Bool
        ) {
            self.route = route
            self.language = language
            self.canSendText = canSendText
            self.canPowerOff = canPowerOff
            self.isMicrophoneOpen = isMicrophoneOpen
        }
    }

    public struct Actions {
        public let togglePerformance: () -> Void
        public let toggleDisplay: () -> Void
        public let toggleAudio: () -> Void
        public let toggleMicrophone: () -> Void
        public let toggleFullscreen: () -> Void
        public let sendText: () -> Void
        public let pressNexus: () -> Void
        public let longPressNexus: () -> Void
        public let disconnect: () -> Void
        public let disconnectAndPowerOff: () -> Void

        public init(
            togglePerformance: @escaping () -> Void,
            toggleDisplay: @escaping () -> Void,
            toggleAudio: @escaping () -> Void,
            toggleMicrophone: @escaping () -> Void,
            toggleFullscreen: @escaping () -> Void,
            sendText: @escaping () -> Void,
            pressNexus: @escaping () -> Void,
            longPressNexus: @escaping () -> Void,
            disconnect: @escaping () -> Void,
            disconnectAndPowerOff: @escaping () -> Void
        ) {
            self.togglePerformance = togglePerformance
            self.toggleDisplay = toggleDisplay
            self.toggleAudio = toggleAudio
            self.toggleMicrophone = toggleMicrophone
            self.toggleFullscreen = toggleFullscreen
            self.sendText = sendText
            self.pressNexus = pressNexus
            self.longPressNexus = longPressNexus
            self.disconnect = disconnect
            self.disconnectAndPowerOff = disconnectAndPowerOff
        }
    }

    @Published public private(set) var context: Context?
    private var actions: Actions?

    public init() {}

    public func register(context: Context, actions: Actions) {
        self.context = context
        self.actions = actions
    }

    public func unregister(for route: AppRouter.Route) {
        guard context?.route == route else { return }
        context = nil
        actions = nil
    }

    public func updateContext(_ context: Context) {
        guard self.context?.route == context.route else { return }
        self.context = context
    }

    public func performTogglePerformance() { actions?.togglePerformance() }
    public func performToggleDisplay() { actions?.toggleDisplay() }
    public func performToggleAudio() { actions?.toggleAudio() }
    public func performToggleMicrophone() { actions?.toggleMicrophone() }
    public func performToggleFullscreen() { actions?.toggleFullscreen() }
    public func performSendText() { actions?.sendText() }
    public func performPressNexus() { actions?.pressNexus() }
    public func performLongPressNexus() { actions?.longPressNexus() }
    public func performDisconnect() { actions?.disconnect() }
    public func performDisconnectAndPowerOff() { actions?.disconnectAndPowerOff() }
}
