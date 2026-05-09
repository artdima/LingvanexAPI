import Foundation
import Testing
@testable import LingvanexAPI

@Suite("Client behaviour")
struct ClientBehaviourTests {

    // MARK: - Decoding

    @Test("Translating returns the translated text")
    func translateReturnsTheResult() async throws {
        let client = LingvanexClient.stubbed(StubTransport(data: try Fixture.data("translate_success")))

        let translation = try await client.translate("Hello", to: .ruRU)

        #expect(translation.text == "Привет")
        #expect(translation.detectedSourceLanguage == .enGB)
        #expect(translation.charactersFromCache == 0)
        #expect(translation.transliteration == nil)
    }

    @Test("Transliteration is decoded when the service sends it")
    func transliterationIsDecodedWhenPresent() async throws {
        let client = LingvanexClient.stubbed(StubTransport(data: try Fixture.data("translate_with_transliteration")))

        let translation = try await client.translate(
            "Hello",
            to: .ruRU,
            options: TranslationOptions(includeTransliteration: true)
        )

        #expect(translation.transliteration?.source == "Hello")
        #expect(translation.transliteration?.target == "Privet")
    }

    @Test("A batch translation comes back as a list")
    func batchTranslationDecodes() async throws {
        let client = LingvanexClient.stubbed(StubTransport(data: try Fixture.data("translate_batch")))

        let translation = try await client.translate(.batch(["Hello", "Goodbye"]), to: .ruRU)

        #expect(translation.output == .batch(["Привет", "Пока"]))
        #expect(translation.text == nil)
        #expect(translation.output.values.count == 2)
    }

    @Test("A response carrying only the translated text still decodes")
    func minimalResponseDecodes() async throws {
        let client = LingvanexClient.stubbed(StubTransport(data: Data(#"{"result":"Привет"}"#.utf8)))

        let translation = try await client.translate("Hello", to: .ruRU)

        #expect(translation.text == "Привет")
        #expect(translation.source == nil)
    }

    @Test("Fields the client does not know about are ignored")
    func unknownFieldsAreIgnored() async throws {
        let body = Data(#"{"result":"Привет","somethingNew":{"nested":1}}"#.utf8)
        let client = LingvanexClient.stubbed(StubTransport(data: body))

        let translation = try await client.translate("Hello", to: .ruRU)

        #expect(translation.text == "Привет")
    }

    @Test("A source language the client cannot parse does not fail the translation")
    func unparsableDetectedLanguageIsDropped() async throws {
        let body = Data(#"{"result":"Привет","from":"nonsense"}"#.utf8)
        let client = LingvanexClient.stubbed(StubTransport(data: body))

        let translation = try await client.translate("Hello", to: .ruRU)

        #expect(translation.text == "Привет")
        #expect(translation.detectedSourceLanguage == nil)
    }

    @Test("The language list decodes")
    func languageListDecodes() async throws {
        let client = LingvanexClient.stubbed(StubTransport(data: try Fixture.data("languages_success")))

        let languages = try await client.languages()

        #expect(languages.count == 2)
        #expect(languages.first?.fullCode == "en_GB")
        #expect(languages.first?.englishName == "English")
        #expect(languages.first?.testWordForSynthesis == "Hello")
        #expect(languages.first?.features.count == 2)
        #expect(languages.last?.localizedName == "Русский")
    }

    @Test("A language entry without the optional fields still decodes")
    func minimalLanguageDecodes() async throws {
        let body = Data(#"{"result":[{"full_code":"en_GB","englishName":"English"}]}"#.utf8)
        let client = LingvanexClient.stubbed(StubTransport(data: body))

        let languages = try await client.languages()
        let language = try #require(languages.first)

        #expect(language.fullCode == "en_GB")
        #expect(language.flagPath == nil)
        #expect(language.features.isEmpty)
    }

    // MARK: - Failures

    @Test("A rejected key is reported as unauthorized", arguments: [401, 403])
    func rejectedKeyIsReported(status: Int) async throws {
        let transport = StubTransport(data: try Fixture.data("translate_error_envelope"), statusCode: status)
        let client = LingvanexClient.stubbed(transport)

        let error = await lingvanexFailure { _ = try await client.translate("Hello", to: .ruRU) }

        #expect(error?.label == "unauthorized")
        #expect(error?.localizedDescription == "API key is invalid")
    }

    @Test("A rate limit carries the Retry-After delay")
    func rateLimitCarriesRetryAfter() async throws {
        let transport = StubTransport(
            data: try Fixture.data("translate_error_envelope"),
            statusCode: 429,
            headers: ["Retry-After": "30"]
        )
        let client = LingvanexClient.stubbed(transport) { $0.retryPolicy = .none }

        let failure = await lingvanexFailure { _ = try await client.translate("Hello", to: .ruRU) }
        let error = try #require(failure)

        guard case let .rateLimited(retryAfter, _) = error else {
            Issue.record("Expected .rateLimited, got \(error.label)")
            return
        }
        #expect(retryAfter == 30)
    }

    @Test("A server failure carries its status", arguments: [500, 503])
    func serverFailureCarriesStatus(status: Int) async throws {
        let transport = StubTransport(data: try Fixture.data("translate_error_envelope"), statusCode: status)
        let client = LingvanexClient.stubbed(transport) { $0.retryPolicy = .none }

        let failure = await lingvanexFailure { _ = try await client.translate("Hello", to: .ruRU) }
        let error = try #require(failure)

        guard case let .server(reported, message) = error else {
            Issue.record("Expected .server, got \(error.label)")
            return
        }
        #expect(reported == status)
        #expect(message == "API key is invalid")
    }

    @Test("A malformed body produces a decoding error that keeps the raw body")
    func malformedBodyProducesDecodingError() async throws {
        let client = LingvanexClient.stubbed(StubTransport(data: Data("{ not json".utf8)))

        let failure = await lingvanexFailure { _ = try await client.translate("Hello", to: .ruRU) }
        let error = try #require(failure)

        guard case let .decoding(_, rawBody) = error else {
            Issue.record("Expected .decoding, got \(error.label)")
            return
        }
        #expect(rawBody == "{ not json")
    }

    @Test("A missing field is reported with the field name")
    func missingFieldIsNamed() async throws {
        let client = LingvanexClient.stubbed(StubTransport(data: Data(#"{"source":"Hello"}"#.utf8)))

        let error = await lingvanexFailure { _ = try await client.translate("Hello", to: .ruRU) }

        #expect(error?.label == "decoding")
        #expect(error?.localizedDescription.contains("result") == true)
    }

    @Test("A transport failure is reported as such")
    func transportFailureIsReported() async throws {
        let client = LingvanexClient.stubbed(
            StubTransport(failure: URLError(.notConnectedToInternet))
        ) { $0.retryPolicy = .none }

        let error = await lingvanexFailure { _ = try await client.translate("Hello", to: .ruRU) }

        #expect(error?.label == "transport")
    }

    @Test("An error inside a 200 envelope is a failure, not a success")
    func errorInsideTheEnvelopeIsAFailure() async throws {
        let client = LingvanexClient.stubbed(StubTransport(data: try Fixture.data("languages_error_in_envelope")))

        let failure = await lingvanexFailure { _ = try await client.languages() }
        let error = try #require(failure)

        guard case let .server(status, message) = error else {
            Issue.record("Expected .server, got \(error.label)")
            return
        }
        #expect(status == 200)
        #expect(message == "Daily limit exceeded")
    }

    @Test("An empty body on a successful status is a failure")
    func emptySuccessIsAFailure() async throws {
        let client = LingvanexClient.stubbed(StubTransport(data: Data()))

        let error = await lingvanexFailure { _ = try await client.translate("Hello", to: .ruRU) }

        #expect(error?.label == "emptyResponse")
    }

    @Test("An empty key is reported instead of being sent")
    func emptyKeyIsReported() async throws {
        let transport = StubTransport(data: try Fixture.data("translate_success"))
        let client = LingvanexClient.stubbed(transport, apiKey: "")

        let error = await lingvanexFailure { _ = try await client.translate("Hello", to: .ruRU) }

        #expect(error?.label == "notConfigured")
        #expect(transport.requests.isEmpty)
    }

    @Test("Two clients keep their own key")
    func clientsDoNotShareConfiguration() async throws {
        let firstTransport = StubTransport(data: try Fixture.data("languages_success"))
        let secondTransport = StubTransport(data: try Fixture.data("languages_success"))

        _ = try await LingvanexClient.stubbed(firstTransport, apiKey: "first-key").languages()
        _ = try await LingvanexClient.stubbed(secondTransport, apiKey: "second-key").languages()

        #expect(firstTransport.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer first-key")
        #expect(secondTransport.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer second-key")
    }
}
