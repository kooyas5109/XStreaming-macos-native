import Foundation
import OSLog

public struct AppLogger: Sendable {
    private let base: OSLog

    public init(subsystem: String = "com.kooyas5109.XStreamingMacNative", category: String) {
        self.base = OSLog(subsystem: subsystem, category: category)
    }

    public func info(_ message: String) {
        os_log("%{public}@", log: base, type: .info, message)
    }

    public func error(_ message: String) {
        os_log("%{public}@", log: base, type: .error, message)
    }

    public static func preview(category: String) -> AppLogger {
        AppLogger(category: category)
    }
}
