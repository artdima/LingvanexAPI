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

    @Test("Only statuses that time can fix are retried")
    func retryableStatuses() {
        #expect(RetryDecision.shouldRetry(status: 429))
        #expect(RetryDecision.shouldRetry(status: 500))
        #expect(RetryDecision.shouldRetry(status: 503))

        #expect(RetryDecision.shouldRetry(status: 200) == false)
        #expect(RetryDecision.shouldRetry(status: 400) == false)
        #expect(RetryDecision.shouldRetry(status: 401) == false)
        #expect(RetryDecision.shouldRetry(status: 404) == false)
    }

    @Test("Only network failures that time can fix are retried")
    func retryableErrors() {
        #expect(RetryDecision.shouldRetry(.transport(underlying: URLError(.timedOut))))
        #expect(RetryDecision.shouldRetry(.transport(underlying: URLError(.networkConnectionLost))))

        #expect(RetryDecision.shouldRetry(.cancelled) == false)
        #expect(RetryDecision.shouldRetry(.transport(underlying: URLError(.cancelled))) == false)
        #expect(RetryDecision.shouldRetry(.unauthorized(message: nil)) == false)
        #expect(RetryDecision.shouldRetry(.emptyResponse) == false)
    }
}

@Suite("Retrying transport")
struct RetryingTransportTests {

    private func client(
        _ stubs: [StubTransport.Stub],
        policy: RetryPolicy = RetryPolicy(maximumAttempts: 3, baseDelay: 1, maximumDelay: 8)
    ) -> (client: LingvanexClient, base: StubTransport, sleeper: RecordingSleeper) {
        let base = StubTransport(sequence: stubs)
        let sleeper = RecordingSleeper()
        let retrying = RetryingTransport(
            wrapping: base,
            policy: policy,
            sleeper: sleeper,
            randomFactor: { _ in 1 }
        )
        return (LingvanexClient.stubbed(retrying), base, sleeper)
    }

    @Test("A rate limit is retried and the second answer is used")
    func rateLimitIsRetried() async throws {
        let context = client([
            StubTransport.Stub(data: try Fixture.data("translate_error_envelope"), statusCode: 429),
            StubTransport.Stub(data: try Fixture.data("translate_success"), statusCode: 200)
        ])

        let translation = try await context.client.translate("Hello", to: .ruRU)

        #expect(translation.text == "Привет")
        #expect(context.base.requests.count == 2)
    }

    @Test("A network timeout is retried")
    func timeoutIsRetried() async throws {
        let context = client([
            StubTransport.Stub(data: nil, error: URLError(.timedOut)),
            StubTransport.Stub(data: try Fixture.data("translate_success"), statusCode: 200)
        ])

        let translation = try await context.client.translate("Hello", to: .ruRU)

        #expect(translation.text == "Привет")
        #expect(context.base.requests.count == 2)
    }

    @Test("A rejected key is not retried")
    func unauthorizedIsNotRetried() async throws {
        let context = client([
            StubTransport.Stub(data: try Fixture.data("translate_error_envelope"), statusCode: 401)
        ])

        let error = await lingvanexFailure { _ = try await context.client.translate("Hello", to: .ruRU) }

        #expect(error?.label == "unauthorized")
        #expect(context.base.requests.count == 1)
    }

    @Test("A bad request is not retried")
    func badRequestIsNotRetried() async throws {
        let context = client([
            StubTransport.Stub(data: try Fixture.data("translate_error_envelope"), statusCode: 400)
        ])

        _ = await lingvanexFailure { _ = try await context.client.translate("Hello", to: .ruRU) }

        #expect(context.base.requests.count == 1)
    }

    @Test("Attempts stop at the configured limit and the last failure is reported")
    func attemptsAreCapped() async throws {
        let context = client([
            StubTransport.Stub(data: try Fixture.data("translate_error_envelope"), statusCode: 500)
        ])

        let error = await lingvanexFailure { _ = try await context.client.translate("Hello", to: .ruRU) }

        #expect(context.base.requests.count == 3)
        #expect(error?.label == "server")
    }

    @Test("The waits between attempts follow the backoff")
    func waitsFollowTheBackoff() async throws {
        let context = client([
            StubTransport.Stub(data: try Fixture.data("translate_error_envelope"), statusCode: 500)
        ])

        _ = await lingvanexFailure { _ = try await context.client.translate("Hello", to: .ruRU) }

        #expect(context.sleeper.delays == [1, 2])
    }

    @Test("Retry-After from the service replaces the computed wait")
    func retryAfterIsHonoured() async throws {
        let context = client([
            StubTransport.Stub(
                data: try Fixture.data("translate_error_envelope"),
                statusCode: 429,
                headers: ["Retry-After": "4"]
            ),
            StubTransport.Stub(data: try Fixture.data("translate_success"), statusCode: 200)
        ])

        _ = try await context.client.translate("Hello", to: .ruRU)

        #expect(context.sleeper.delays == [4])
    }

    @Test("A successful call is sent once")
    func successIsNotRetried() async throws {
        let context = client([
            StubTransport.Stub(data: try Fixture.data("translate_success"), statusCode: 200)
        ])

        _ = try await context.client.translate("Hello", to: .ruRU)

        #expect(context.base.requests.count == 1)
        #expect(context.sleeper.delays.isEmpty)
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

    @Test("An API key masks itself when printed")
    func apiKeyMasksItself() {
        let key = APIKey("a_W9cN8eb6C6EPY00UtltX3SaMoRchGD3LElr")

        #expect("\(key)".contains("a_W9cN8eb6C6EPY00UtltX3SaMoRchGD3LElr") == false)
        #expect("\(key)" == "a_W9…LElr")
    }

    @Test("A traced request logs its method, url and redacted headers")
    func requestIsTraced() async throws {
        let recorder = LogRecorder()
        let base = StubTransport(data: try Fixture.data("translate_success"))
        let client = LingvanexClient.stubbed(
            LoggingTransport(wrapping: base, sink: { recorder.append($0) }),
            apiKey: "a_W9cN8eb6C6EPY00UtltX3SaMoRchGD3LElr"
        )

        _ = try await client.translate("Hello", to: .ruRU)

        #expect(recorder.lines.count == 2)
        #expect(recorder.lines.first?.contains("POST") == true)
        #expect(recorder.lines.first?.contains("/translate") == true)
        #expect(recorder.lines.first?.contains("a_W9cN8eb6C6EPY00UtltX3SaMoRchGD3LElr") == false)
        #expect(recorder.lines.last?.contains("200") == true)
    }
}
