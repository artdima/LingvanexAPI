import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Waits before the next attempt. Abstracted so the retry loop can be tested without real time.
protocol RetryScheduler {
    func schedule(after delay: TimeInterval, work: @escaping () -> Void)
}

struct DispatchRetryScheduler: RetryScheduler {

    func schedule(after delay: TimeInterval, work: @escaping () -> Void) {
        guard delay > 0 else {
            work()
            return
        }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay, execute: work)
    }
}

/// Adds retries to any transport without the client knowing about them.
final class RetryingTransport: HTTPTransport {

    private let base: HTTPTransport
    private let policy: RetryPolicy
    private let scheduler: RetryScheduler
    private let randomFactor: (ClosedRange<Double>) -> Double

    init(
        wrapping base: HTTPTransport,
        policy: RetryPolicy = .default,
        scheduler: RetryScheduler = DispatchRetryScheduler(),
        randomFactor: @escaping (ClosedRange<Double>) -> Double = { Double.random(in: $0) }
    ) {
        self.base = base
        self.policy = policy
        self.scheduler = scheduler
        self.randomFactor = randomFactor
    }

    func send(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        attempt(1, request, completion)
    }

    private func attempt(
        _ number: Int,
        _ request: URLRequest,
        _ completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        base.send(request) { [weak self] data, response, error in
            guard let self else {
                completion(data, response, error)
                return
            }

            guard number < policy.maximumAttempts,
                  RetryDecision.shouldRetry(response: response, error: error) else {
                completion(data, response, error)
                return
            }

            let retryAfter = (response as? HTTPURLResponse).flatMap(RetryDecision.retryAfter(for:))
            let delay = policy.delay(forAttempt: number, retryAfter: retryAfter, randomFactor: randomFactor)

            scheduler.schedule(after: delay) { [weak self] in
                guard let self else {
                    completion(data, response, error)
                    return
                }
                attempt(number + 1, request, completion)
            }
        }
    }
}
