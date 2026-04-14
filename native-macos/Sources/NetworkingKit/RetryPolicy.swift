import Foundation

public struct RetryPolicy: Equatable, Sendable {
    public let maxAttempts: Int
    public let retryableStatusCodes: Set<Int>
    public let retryableURLErrorCodes: Set<URLError.Code>

    public init(
        maxAttempts: Int = 3,
        retryableStatusCodes: Set<Int> = [408, 425, 429, 500, 502, 503, 504],
        retryableURLErrorCodes: Set<URLError.Code> = [.timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost]
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.retryableStatusCodes = retryableStatusCodes
        self.retryableURLErrorCodes = retryableURLErrorCodes
    }

    public func shouldRetry(statusCode: Int, attempt: Int) -> Bool {
        guard attempt < maxAttempts else {
            return false
        }

        return retryableStatusCodes.contains(statusCode)
    }

    public func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else {
            return false
        }

        guard let urlError = error as? URLError else {
            return false
        }

        return retryableURLErrorCodes.contains(urlError.code)
    }
}
