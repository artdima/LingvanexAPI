import Foundation
import Testing
@testable import LingvanexAPI

@Suite("Behaviour as it is today")
struct CharacterizationTests {

    @Test("The only response shape that decodes is the one carrying transliteration")
    func responseWithTransliterationDecodes() async throws {
        let api = LingvanexAPI.stubbed(StubTransport(data: try Fixture.data("translate_with_transliteration")))

        let outcome = await api.translated()

        let translation = try #require(outcome.value)
        #expect(translation.result == "Привет")
        #expect(translation.targetTransliteration == "Privet")
    }

    @Test("Translating returns the translated text")
    func translateReturnsTheResult() async throws {
        let api = LingvanexAPI.stubbed(StubTransport(data: try Fixture.data("translate_success")))

        let outcome = await api.translated()

        withKnownIssue("E4: the model requires transliteration fields the server only sends when asked") {
            let translation = try #require(outcome.value)
            #expect(translation.result == "Привет")
        }
    }

    @Test("A server response without transliteration produces neither a result nor an error")
    func responseWithoutTransliterationIsDroppedSilently() async throws {
        let api = LingvanexAPI.stubbed(StubTransport(data: try Fixture.data("translate_success")))

        let outcome = await api.translated()

        #expect(outcome.value == nil)
        #expect(outcome.error == nil)
    }

    @Test("An HTTP failure produces neither a result nor an error", arguments: [400, 401, 403, 429, 500, 503])
    func httpFailureLosesTheError(status: Int) async throws {
        let transport = StubTransport(data: try Fixture.data("translate_error_envelope"), statusCode: status)
        let api = LingvanexAPI.stubbed(transport)

        let outcome = await api.translated()

        #expect(outcome.value == nil)
        #expect(outcome.error == nil)
    }

    @Test("The error message the server sends never reaches the caller")
    func serverMessageIsDiscarded() async throws {
        let transport = StubTransport(data: try Fixture.data("translate_error_envelope"), statusCode: 401)
        let api = LingvanexAPI.stubbed(transport)

        let outcome = await api.translated()

        #expect(outcome.error == nil)
    }

    @Test("A malformed body produces neither a result nor a decoding error")
    func malformedBodyLosesTheDecodingError() async {
        let api = LingvanexAPI.stubbed(StubTransport(data: Data("{ not json".utf8)))

        let outcome = await api.translated()

        #expect(outcome.value == nil)
        #expect(outcome.error == nil)
    }

    @Test("A transport failure is the one failure that does reach the caller")
    func transportFailureIsPropagated() async {
        let api = LingvanexAPI.stubbed(StubTransport(failure: URLError(.notConnectedToInternet)))

        let outcome = await api.translated()

        #expect(outcome.value == nil)
        #expect(outcome.error != nil)
    }

    @Test("The language list decodes")
    func languageListDecodes() async throws {
        let api = LingvanexAPI.stubbed(StubTransport(data: try Fixture.data("languages_success")))

        let outcome = await api.languageList()

        let languages = try #require(outcome.value)
        #expect(languages.count == 2)
        #expect(languages.first?.fullCode == "en_GB")
        #expect(languages.first?.englishName == "English")
        #expect(languages.first?.modes.count == 2)
    }

    @Test("A 200 response carrying an error message is reported as success")
    func errorInsideTheEnvelopeIsIgnored() async throws {
        let api = LingvanexAPI.stubbed(StubTransport(data: try Fixture.data("languages_error_in_envelope")))

        let outcome = await api.languageList()

        #expect(outcome.value?.isEmpty == true)
        #expect(outcome.error == nil)
    }

    @Test("Two clients keep their own key")
    func clientsDoNotShareConfiguration() async throws {
        let firstTransport = StubTransport(data: try Fixture.data("languages_success"))
        let secondTransport = StubTransport(data: try Fixture.data("languages_success"))
        let first = LingvanexAPI.stubbed(firstTransport, key: "first-key")
        let second = LingvanexAPI.stubbed(secondTransport, key: "second-key")

        _ = await first.languageList()
        _ = await second.languageList()

        let firstAuthorization = firstTransport.lastRequest?.value(forHTTPHeaderField: "Authorization")
        let secondAuthorization = secondTransport.lastRequest?.value(forHTTPHeaderField: "Authorization")
        #expect(firstAuthorization == "Bearer first-key")
        #expect(secondAuthorization == "Bearer second-key")
    }
}
