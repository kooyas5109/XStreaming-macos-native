import Foundation
import Testing
@testable import NetworkingKit

@Test
func retryPolicyRetriesTransientStatusCodeBeforeMaxAttempts() {
    let policy = RetryPolicy(maxAttempts: 3)
    #expect(policy.shouldRetry(statusCode: 503, attempt: 1) == true)
    #expect(policy.shouldRetry(statusCode: 503, attempt: 3) == false)
}

@Test
func retryPolicyRetriesKnownURLErrorBeforeMaxAttempts() {
    let policy = RetryPolicy(maxAttempts: 2)
    let error = URLError(.timedOut)
    #expect(policy.shouldRetry(error: error, attempt: 1) == true)
    #expect(policy.shouldRetry(error: error, attempt: 2) == false)
}

@Test
func retryPolicyDoesNotRetryUnknownErrors() {
    let policy = RetryPolicy()
    let error = NSError(domain: "test", code: 1)
    #expect(policy.shouldRetry(error: error, attempt: 1) == false)
}
