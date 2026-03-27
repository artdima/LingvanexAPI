import Foundation

/// How a transient failure is retried. Exponential backoff with jitter, because a fleet
/// of clients retrying on the same schedule is what turns an overload into an outage.
struct RetryPolicy: Equatable {

    static let `default` = RetryPolicy()
    static let none = RetryPolicy(maximumAttempts: 1)

    var maximumAttempts: Int = 3
    var baseDelay: TimeInterval = 0.5
    var maximumDelay: TimeInterval = 8
    var jitter: ClosedRange<Double> = 0.8 ... 1.2

    func delay(
        forAttempt attempt: Int,
        retryAfter: TimeInterval?,
        randomFactor: (ClosedRange<Double>) -> Double
    ) -> TimeInterval {
        if let retryAfter {
            return min(max(retryAfter, 0), maximumDelay)
        }
        let exponential = baseDelay * pow(2, Double(max(attempt - 1, 0)))
        return min(exponential, maximumDelay) * randomFactor(jitter)
    }
}

/// Decides whether an answer is worth another attempt.
enum RetryDecision {

    static func retryAfter(for response: HTTPURLResponse) -> TimeInterval? {
        guard let header = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return TimeInterval(header.trimmingCharacters(in: .whitespaces))
    }

    /// Retries the failures that time can fix, and nothing else: a rejected key or a bad
    /// request will be rejected just as firmly on the second try.
    static func shouldRetry(response: URLResponse?, error: Error?) -> Bool {
        if let urlError = error as? URLError {
            return retryableURLErrorCodes.contains(urlError.code)
        }
        if error != nil {
            return false
        }
        guard let response = response as? HTTPURLResponse else {
            return false
        }
        return response.statusCode == 429 || (500 ..< 600).contains(response.statusCode)
    }

    private static let retryableURLErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .networkConnectionLost,
        .notConnectedToInternet,
        .cannotConnectToHost,
        .cannotFindHost,
        .dnsLookupFailed,
        .resourceUnavailable
    ]
}
