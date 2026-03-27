import Foundation
import Testing
@testable import LingvanexAPI

@Suite("Retry policy")
struct RetryPolicyTests {

    private let fixedJitter: (ClosedRange<Double>) -> Double = { _ in 1 }

    @Test("Backoff grows exponentially")
    func backoffGrows() {
        let policy = RetryPolicy(maximumAttempts: 5, baseDelay: 0.5, maximumDelay: 8)

        #expect(policy.delay(forAttempt: 1, retryAfter: nil, randomFactor: fixedJitter) == 0.5)
        #expect(policy.delay(forAttempt: 2, retryAfter: nil, randomFactor: fixedJitter) == 1)
        #expect(policy.delay(forAttempt: 3, retryAfter: nil, randomFactor: fixedJitter) == 2)
        #expect(policy.delay(forAttempt: 4, retryAfter: nil, randomFactor: fixedJitter) == 4)
    }

    @Test("Backoff is capped")
    func backoffIsCapped() {
        let policy = RetryPolicy(maximumAttempts: 20, baseDelay: 1, maximumDelay: 3)

        #expect(policy.delay(forAttempt: 10, retryAfter: nil, randomFactor: fixedJitter) == 3)
    }

    @Test("Retry-After wins over the computed backoff")
    func retryAfterWins() {
        let policy = RetryPolicy(baseDelay: 0.5, maximumDelay: 8)

        #expect(policy.delay(forAttempt: 1, retryAfter: 5, randomFactor: fixedJitter) == 5)
        #expect(policy.delay(forAttempt: 1, retryAfter: 100, randomFactor: fixedJitter) == 8)
        #expect(policy.delay(forAttempt: 1, retryAfter: -3, randomFactor: fixedJitter) == 0)
    }

    @Test("Jitter spreads the delay around the computed value")
    func jitterIsApplied() {
        let policy = RetryPolicy(baseDelay: 1, jitter: 0.5 ... 1.5)

        #expect(policy.delay(forAttempt: 1, retryAfter: nil, randomFactor: { $0.lowerBound }) == 0.5)
        #expect(policy.delay(forAttempt: 1, retryAfter: nil, randomFactor: { $0.upperBound }) == 1.5)
    }

    @Test("Only failures that time can fix are retried")
    func retryableOutcomes() throws {
        let url = try #require(URL(string: "https://example.com"))
        func response(_ status: Int) -> HTTPURLResponse? {
            HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
        }

        #expect(RetryDecision.shouldRetry(response: response(429), error: nil))
        #expect(RetryDecision.shouldRetry(response: response(500), error: nil))
        #expect(RetryDecision.shouldRetry(response: response(503), error: nil))
        #expect(RetryDecision.shouldRetry(response: nil, error: URLError(.timedOut)))
        #expect(RetryDecision.shouldRetry(response: nil, error: URLError(.networkConnectionLost)))

        #expect(RetryDecision.shouldRetry(response: response(200), error: nil) == false)
        #expect(RetryDecision.shouldRetry(response: response(400), error: nil) == false)
        #expect(RetryDecision.shouldRetry(response: response(401), error: nil) == false)
        #expect(RetryDecision.shouldRetry(response: response(404), error: nil) == false)
        #expect(RetryDecision.shouldRetry(response: nil, error: URLError(.cancelled)) == false)
    }
}

@Suite("Retrying transport")
struct RetryingTransportTests {

    private func envelope() throws -> Data {
        try Fixture.data("translate_error_envelope")
    }

    private func client(
        _ stubs: [StubTransport.Stub],
        policy: RetryPolicy = RetryPolicy(maximumAttempts: 3, baseDelay: 1, maximumDelay: 8)
    ) -> (api: LingvanexAPI, base: StubTransport, clock: ImmediateScheduler) {
        let base = StubTransport(sequence: stubs)
        let clock = ImmediateScheduler()
        let retrying = RetryingTransport(
            wrapping: base,
            policy: policy,
            scheduler: clock,
            randomFactor: { _ in 1 }
        )
        let api = LingvanexAPI(transport: retrying)
        api.start(with: "test-key")
        return (api, base, clock)
    }

    @Test("A rate limit is retried and the second answer is used")
    func rateLimitIsRetried() async throws {
        let success = try Fixture.data("translate_success")
        let context = client([
            StubTransport.Stub(data: try envelope(), statusCode: 429),
            StubTransport.Stub(data: success, statusCode: 200)
        ])

        let outcome = await context.api.translated()

        #expect(outcome.value?.result == "Привет")
        #expect(context.base.requests.count == 2)
    }

    @Test("A network timeout is retried")
    func timeoutIsRetried() async throws {
        let success = try Fixture.data("translate_success")
        let context = client([
            StubTransport.Stub(data: nil, error: URLError(.timedOut)),
            StubTransport.Stub(data: success, statusCode: 200)
        ])

        let outcome = await context.api.translated()

        #expect(outcome.value?.result == "Привет")
        #expect(context.base.requests.count == 2)
    }

    @Test("A rejected key is not retried")
    func unauthorizedIsNotRetried() async throws {
        let context = client([StubTransport.Stub(data: try envelope(), statusCode: 401)])

        let outcome = await context.api.translated()

        #expect((outcome.error as? LingvanexError)?.label == "unauthorized")
        #expect(context.base.requests.count == 1)
    }

    @Test("A bad request is not retried")
    func badRequestIsNotRetried() async throws {
        let context = client([StubTransport.Stub(data: try envelope(), statusCode: 400)])

        _ = await context.api.translated()

        #expect(context.base.requests.count == 1)
    }

    @Test("Attempts stop at the configured limit and the last failure is reported")
    func attemptsAreCapped() async throws {
        let context = client([StubTransport.Stub(data: try envelope(), statusCode: 500)])

        let outcome = await context.api.translated()

        #expect(context.base.requests.count == 3)
        #expect((outcome.error as? LingvanexError)?.label == "server")
    }

    @Test("The waits between attempts follow the backoff")
    func waitsFollowTheBackoff() async throws {
        let context = client([StubTransport.Stub(data: try envelope(), statusCode: 500)])

        _ = await context.api.translated()

        #expect(context.clock.delays == [1, 2])
    }

    @Test("Retry-After from the service replaces the computed wait")
    func retryAfterIsHonoured() async throws {
        let context = client([
            StubTransport.Stub(data: try envelope(), statusCode: 429, headers: ["Retry-After": "4"]),
            StubTransport.Stub(data: try Fixture.data("translate_success"), statusCode: 200)
        ])

        _ = await context.api.translated()

        #expect(context.clock.delays == [4])
    }

    @Test("A successful call is sent once")
    func successIsNotRetried() async throws {
        let context = client([StubTransport.Stub(data: try Fixture.data("translate_success"), statusCode: 200)])

        _ = await context.api.translated()

        #expect(context.base.requests.count == 1)
        #expect(context.clock.delays.isEmpty)
    }
}

@Suite("Logging transport")
struct LoggingTransportTests {

    @Test("The key never reaches the log")
    func authorizationIsRedacted() {
        let redacted = LoggingTransport.redactAuthorization("Bearer a_W9cN8eb6C6EPY00UtltX3SaMoRchGD3LElr")

        #expect(redacted.contains("a_W9cN8eb6C6EPY00UtltX3SaMoRchGD3LElr") == false)
        #expect(redacted.hasPrefix("Bearer a_W9"))
        #expect(redacted.hasSuffix("LElr"))
    }

    @Test("A short value is hidden entirely")
    func shortValueIsFullyHidden() {
        #expect(LoggingTransport.redactAuthorization("Bearer short") == "Bearer ***")
    }

    @Test("A traced request logs its method, url and redacted headers")
    func requestIsTraced() async throws {
        let recorder = LogRecorder()
        var configuration = LingvanexConfiguration()
        configuration.apiKey = "a_W9cN8eb6C6EPY00UtltX3SaMoRchGD3LElr"

        let base = StubTransport(data: try Fixture.data("translate_success"))
        let api = LingvanexAPI(
            configuration: configuration,
            transport: LoggingTransport(wrapping: base, sink: { recorder.append($0) })
        )

        _ = await api.translated()

        let lines = recorder.lines
        #expect(lines.count == 2)
        #expect(lines.first?.contains("POST") == true)
        #expect(lines.first?.contains("/translate") == true)
        #expect(lines.first?.contains("a_W9cN8eb6C6EPY00UtltX3SaMoRchGD3LElr") == false)
        #expect(lines.last?.contains("200") == true)
    }
}
