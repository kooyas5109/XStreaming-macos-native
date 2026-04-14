import Foundation

@MainActor
public final class AudioSessionCoordinator: @unchecked Sendable {
    public private(set) var isPrepared = false
    public private(set) var isActive = false
    public private(set) var isMuted = false

    public init() {}

    public func prepare() {
        isPrepared = true
    }

    public func activate() {
        if isPrepared == false {
            prepare()
        }
        isActive = true
    }

    public func deactivate() {
        isActive = false
    }

    public func setMuted(_ muted: Bool) {
        isMuted = muted
    }
}
