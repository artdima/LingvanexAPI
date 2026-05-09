import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Waits between attempts. Injected so the backoff can be asserted without spending real time.
public protocol RetrySleeper {
    func sleep(for duration: TimeInterval) async throws
}

public struct TaskSleeper: RetrySleeper {

    public init() {}

    public func sleep(for duration: TimeInterval) async throws {
        guard duration > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
}

/// Adds retries to any transport without the client knowing about them.
public struct RetryingTransport: HTTPTransport {

    private let base: HTTPTransport
    private let policy: RetryPolicy
    private let sleeper: RetrySleeper
    private let randomFactor: (ClosedRange<Double>) -> Double

    public init(
        wrapping base: HTTPTransport,
        policy: RetryPolicy = .default,
        sleeper: RetrySleeper = TaskSleeper(),
        randomFactor: @escaping (ClosedRange<Double>) -> Double = { Double.random(in: $0) }
    ) {
        self.base = base
        self.policy = policy
        self.sleeper = sleeper
        self.randomFactor = randomFactor
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var attempt = 1

        while true {
            let isLastAttempt = attempt >= policy.maximumAttempts

            do {
                let (data, response) = try await base.send(request)

                guard !isLastAttempt, RetryDecision.shouldRetry(status: response.statusCode) else {
                    return (data, response)
                }
                try await wait(before: attempt, retryAfter: RetryDecision.retryAfter(for: response))
            } catch let error as LingvanexError {
                guard !isLastAttempt, RetryDecision.shouldRetry(error) else { throw error }
                try await wait(before: attempt, retryAfter: nil)
            }

            attempt += 1
        }
    }

    private func wait(before attempt: Int, retryAfter: TimeInterval?) async throws {
        let delay = policy.delay(forAttempt: attempt, retryAfter: retryAfter, randomFactor: randomFactor)
        do {
            try await sleeper.sleep(for: delay)
        } catch {
            throw LingvanexError.cancelled
        }
    }
}
