import Foundation
import Testing
@testable import LingvanexAPI

@Suite("Client behaviour")
struct ClientBehaviourTests {

    // MARK: - Decoding

    @Test("Translating returns the translated text")
    func translateReturnsTheResult() async throws {
        let api = LingvanexAPI.stubbed(StubTransport(data: try Fixture.data("translate_success")))

        let outcome = await api.translated()

        let translation = try #require(outcome.value)
        #expect(translation.result == "Привет")
        #expect(translation.source == "Hello")
        #expect(translation.detectedSourceLanguage == "en_GB")
        #expect(translation.charactersFromCache == 0)
        #expect(translation.transliteration == nil)
        #expect(outcome.error == nil)
    }

    @Test("Transliteration is decoded when the service sends it")
    func transliterationIsDecodedWhenPresent() async throws {
        let api = LingvanexAPI.stubbed(StubTransport(data: try Fixture.data("translate_with_transliteration")))

        let outcome = await api.translated()

        let translation = try #require(outcome.value)
        #expect(translation.transliteration?.source == "Hello")
        #expect(translation.transliteration?.target == "Privet")
    }

    @Test("A response carrying only the translated text still decodes")
    func minimalResponseDecodes() async throws {
        let body = Data(#"{"result":"Привет"}"#.utf8)
        let api = LingvanexAPI.stubbed(StubTransport(data: body))

        let outcome = await api.translated()

        let translation = try #require(outcome.value)
        #expect(translation.result == "Привет")
        #expect(translation.source == nil)
        #expect(translation.transliteration == nil)
    }

    @Test("Fields the client does not know about are ignored")
    func unknownFieldsAreIgnored() async throws {
        let body = Data(#"{"result":"Привет","somethingNew":{"nested":1}}"#.utf8)
        let api = LingvanexAPI.stubbed(StubTransport(data: body))

        let outcome = await api.translated()

        #expect(outcome.value?.result == "Привет")
    }

    @Test("The language list decodes")
    func languageListDecodes() async throws {
        let api = LingvanexAPI.stubbed(StubTransport(data: try Fixture.data("languages_success")))

        let outcome = await api.languageList()

        let languages = try #require(outcome.value)
        #expect(languages.count == 2)
        #expect(languages.first?.fullCode == "en_GB")
        #expect(languages.first?.code == "en")
        #expect(languages.first?.englishName == "English")
        #expect(languages.first?.testWordForSynthesis == "Hello")
        #expect(languages.first?.features.count == 2)
        #expect(languages.first?.features.first?.isEnabled == true)
        #expect(languages.last?.localizedName == "Русский")
    }

    @Test("A language entry without the optional fields still decodes")
    func minimalLanguageDecodes() async throws {
        let body = Data(#"{"result":[{"full_code":"en_GB","englishName":"English"}]}"#.utf8)
        let api = LingvanexAPI.stubbed(StubTransport(data: body))

        let outcome = await api.languageList()

        let language = try #require(outcome.value?.first)
        #expect(language.fullCode == "en_GB")
        #expect(language.flagPath == nil)
        #expect(language.features.isEmpty)
    }

    // MARK: - Failures

    @Test("A rejected key is reported as unauthorized", arguments: [401, 403])
    func rejectedKeyIsReported(status: Int) async throws {
        let transport = StubTransport(data: try Fixture.data("translate_error_envelope"), statusCode: status)
        let api = LingvanexAPI.stubbed(transport)

        let outcome = await api.translated()

        #expect(outcome.value == nil)
        let error = try #require(outcome.error as? LingvanexError)
        #expect(error.label == "unauthorized")
    }

    @Test("The message the server sends reaches the caller")
    func serverMessageReachesTheCaller() async throws {
        let transport = StubTransport(data: try Fixture.data("translate_error_envelope"), statusCode: 401)
        let api = LingvanexAPI.stubbed(transport)

        let outcome = await api.translated()

        let error = try #require(outcome.error as? LingvanexError)
        guard case let .unauthorized(message) = error else {
            Issue.record("Expected .unauthorized, got \(error.label)")
            return
        }
        #expect(message == "API key is invalid")
        #expect(error.localizedDescription == "API key is invalid")
    }

    @Test("A rate limit carries the Retry-After delay")
    func rateLimitCarriesRetryAfter() async throws {
        let transport = StubTransport(
            data: try Fixture.data("translate_error_envelope"),
            statusCode: 429,
            headers: ["Retry-After": "30"]
        )
        let api = LingvanexAPI.stubbed(transport)

        let outcome = await api.translated()

        let error = try #require(outcome.error as? LingvanexError)
        guard case let .rateLimited(retryAfter, _) = error else {
            Issue.record("Expected .rateLimited, got \(error.label)")
            return
        }
        #expect(retryAfter == 30)
    }

    @Test("A server failure carries its status", arguments: [500, 503])
    func serverFailureCarriesStatus(status: Int) async throws {
        let transport = StubTransport(data: try Fixture.data("translate_error_envelope"), statusCode: status)
        let api = LingvanexAPI.stubbed(transport)

        let outcome = await api.translated()

        let error = try #require(outcome.error as? LingvanexError)
        guard case let .server(reported, message) = error else {
            Issue.record("Expected .server, got \(error.label)")
            return
        }
        #expect(reported == status)
        #expect(message == "API key is invalid")
    }

    @Test("A malformed body produces a decoding error that keeps the raw body")
    func malformedBodyProducesDecodingError() async throws {
        let api = LingvanexAPI.stubbed(StubTransport(data: Data("{ not json".utf8)))

        let outcome = await api.translated()

        let error = try #require(outcome.error as? LingvanexError)
        guard case let .decoding(_, rawBody) = error else {
            Issue.record("Expected .decoding, got \(error.label)")
            return
        }
        #expect(rawBody == "{ not json")
    }

    @Test("A missing field is reported with the field name")
    func missingFieldIsNamed() async throws {
        let api = LingvanexAPI.stubbed(StubTransport(data: Data(#"{"source":"Hello"}"#.utf8)))

        let outcome = await api.translated()

        let error = try #require(outcome.error as? LingvanexError)
        #expect(error.label == "decoding")
        #expect(error.localizedDescription.contains("result"))
    }

    @Test("A transport failure is reported as such")
    func transportFailureIsReported() async throws {
        let api = LingvanexAPI.stubbed(StubTransport(failure: URLError(.notConnectedToInternet)))

        let outcome = await api.translated()

        let error = try #require(outcome.error as? LingvanexError)
        #expect(error.label == "transport")
    }

    @Test("An error inside a 200 envelope is a failure, not a success")
    func errorInsideTheEnvelopeIsAFailure() async throws {
        let api = LingvanexAPI.stubbed(StubTransport(data: try Fixture.data("languages_error_in_envelope")))

        let outcome = await api.languageList()

        #expect(outcome.value == nil)
        let error = try #require(outcome.error as? LingvanexError)
        guard case let .server(status, message) = error else {
            Issue.record("Expected .server, got \(error.label)")
            return
        }
        #expect(status == 200)
        #expect(message == "Daily limit exceeded")
    }

    @Test("An empty body on a successful status is a failure")
    func emptySuccessIsAFailure() async throws {
        let api = LingvanexAPI.stubbed(StubTransport(data: Data()))

        let outcome = await api.translated()

        #expect((outcome.error as? LingvanexError)?.label == "emptyResponse")
    }

    @Test("Translating without a key fails instead of crashing")
    func missingKeyIsReportedNotCrashed() async throws {
        let api = LingvanexAPI(transport: StubTransport(data: nil))

        let outcome = await api.translated()

        #expect(outcome.value == nil)
        #expect((outcome.error as? LingvanexError)?.label == "notConfigured")
    }

    // MARK: - The invariant the old client broke

    @Test("Every outcome carries either a value or an error, never neither")
    func noOutcomeIsSilent() async throws {
        let success = try Fixture.data("translate_success")
        let envelope = try Fixture.data("translate_error_envelope")
        let transports: [StubTransport] = [
            StubTransport(data: success),
            StubTransport(data: envelope, statusCode: 401),
            StubTransport(data: envelope, statusCode: 429),
            StubTransport(data: envelope, statusCode: 500),
            StubTransport(data: Data("{ not json".utf8)),
            StubTransport(data: Data()),
            StubTransport(failure: URLError(.timedOut))
        ]

        for transport in transports {
            let outcome = await LingvanexAPI.stubbed(transport).translated()
            #expect(outcome.value != nil || outcome.error != nil)
        }
    }

    @Test("Two clients keep their own key")
    func clientsDoNotShareConfiguration() async throws {
        let firstTransport = StubTransport(data: try Fixture.data("languages_success"))
        let secondTransport = StubTransport(data: try Fixture.data("languages_success"))
        let first = LingvanexAPI.stubbed(firstTransport, key: "first-key")
        let second = LingvanexAPI.stubbed(secondTransport, key: "second-key")

        _ = await first.languageList()
        _ = await second.languageList()

        #expect(firstTransport.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer first-key")
        #expect(secondTransport.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer second-key")
    }
}
