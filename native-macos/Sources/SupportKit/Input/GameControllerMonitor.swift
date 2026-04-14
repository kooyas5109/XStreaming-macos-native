import Foundation
@preconcurrency import GameController

public struct ConnectedGameController: Equatable, Sendable {
    public let id: String
    public let vendorName: String?

    public init(id: String, vendorName: String?) {
        self.id = id
        self.vendorName = vendorName
    }
}

@MainActor
public final class GameControllerMonitor: NSObject {
    public private(set) var controllers: [ConnectedGameController]

    private let notificationCenter: NotificationCenter

    public init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        self.controllers = GCController.controllers().map(Self.makeConnectedController(from:))
        super.init()
        registerObservers()
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    public var primaryController: ConnectedGameController? {
        controllers.first
    }

    private func handleDidConnect(_ controller: GCController) {
        let connected = Self.makeConnectedController(from: controller)
        if controllers.contains(connected) == false {
            controllers.append(connected)
        }
    }

    private func handleDidDisconnect(_ controller: GCController) {
        let disconnected = Self.makeConnectedController(from: controller)
        controllers.removeAll { $0 == disconnected }
    }

    private func registerObservers() {
        notificationCenter.addObserver(
            self,
            selector: #selector(controllerDidConnect(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(controllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )
    }

    @objc
    private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        handleDidConnect(controller)
    }

    @objc
    private func controllerDidDisconnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        handleDidDisconnect(controller)
    }

    private static func makeConnectedController(from controller: GCController) -> ConnectedGameController {
        ConnectedGameController(
            id: String(ObjectIdentifier(controller).hashValue),
            vendorName: controller.vendorName
        )
    }
}
