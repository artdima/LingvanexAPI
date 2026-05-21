import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// How a transient failure is retried. Exponential backoff with jitter, because a fleet
/// of clients retrying on the same schedule is what turns an overload into an outage.
public struct RetryPolicy: Equatable, Sendable {

    public static let `default` = RetryPolicy()
    public static let none = RetryPolicy(maximumAttempts: 1)

    public var maximumAttempts: Int
    public var baseDelay: TimeInterval
    public var maximumDelay: TimeInterval
    public var jitter: ClosedRange<Double>

    public init(
        maximumAttempts: Int = 3,
        baseDelay: TimeInterval = 0.5,
        maximumDelay: TimeInterval = 8,
        jitter: ClosedRange<Double> = 0.8 ... 1.2
    ) {
        self.maximumAttempts = maximumAttempts
        self.baseDelay = baseDelay
        self.maximumDelay = maximumDelay
        self.jitter = jitter
    }

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

    /// Retries the failures that time can fix, and nothing else: a rejected key or a bad
    /// request will be rejected just as firmly on the second try.
    static func shouldRetry(status: Int) -> Bool {
        status == 429 || (500 ..< 600).contains(status)
    }

    static func shouldRetry(_ error: LingvanexError) -> Bool {
        guard case let .transport(underlying) = error,
              let urlError = underlying as? URLError else {
            return false
        }
        return retryableURLErrorCodes.contains(urlError.code)
    }

    static func retryAfter(for response: HTTPURLResponse) -> TimeInterval? {
        guard let header = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return TimeInterval(header.trimmingCharacters(in: .whitespaces))
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
