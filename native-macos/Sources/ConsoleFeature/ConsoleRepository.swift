import SharedDomain

public protocol ConsoleRepository: Sendable {
    func fetchConsoles() async throws -> [ConsoleDevice]
    func powerOn(consoleID: String) async throws
    func powerOff(consoleID: String) async throws
    func sendText(consoleID: String, text: String) async throws
}

public struct PreviewConsoleRepository: ConsoleRepository {
    private let consoles: [ConsoleDevice]

    public init(consoles: [ConsoleDevice]) {
        self.consoles = consoles
    }

    public func fetchConsoles() async throws -> [ConsoleDevice] {
        consoles
    }

    public func powerOn(consoleID: String) async throws {}
    public func powerOff(consoleID: String) async throws {}
    public func sendText(consoleID: String, text: String) async throws {}
}
