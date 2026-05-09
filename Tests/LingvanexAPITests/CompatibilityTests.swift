import Foundation
import Testing
@testable import LingvanexAPI

// This suite calls the 0.x API on purpose, so deprecation warnings here are expected
// and are the only ones in the package. Swift Testing refuses @Test on a deprecated
// declaration, so they cannot be silenced by marking the suite deprecated; CI enforces
// warnings-as-errors on the library build instead, where there are none.
@Suite("Compatibility with the 0.x API")
struct CompatibilityTests {

    private func legacy(_ transport: HTTPTransport, apiKey: String = "test-key") -> LingvanexAPI {
        var configuration = LingvanexConfiguration(apiKey: APIKey(apiKey))
        configuration.transport = transport
        let api = LingvanexAPI(configuration: configuration)
        api.start(with: apiKey)
        return api
    }

    private func translated(_ api: LingvanexAPI) async -> (value: Translation?, error: Error?) {
        await withCheckedContinuation { continuation in
            api.translate("en_GB", "ru_RU", "Hello") { translation, error in
                continuation.resume(returning: (value: translation, error: error))
            }
        }
    }

    @Test("The old completion API returns what the new one returns")
    func translationParity() async throws {
        let body = try Fixture.data("translate_success")
        let api = legacy(StubTransport(data: body))
        let client = LingvanexClient.stubbed(StubTransport(data: body))

        let legacyOutcome = await translated(api)
        let modern = try await client.translate("Hello", from: .enGB, to: .ruRU)

        #expect(legacyOutcome.value == modern)
        #expect(legacyOutcome.error == nil)
    }

    @Test("The old language list returns what the new one returns")
    func languageListParity() async throws {
        let body = try Fixture.data("languages_success")
        let api = legacy(StubTransport(data: body))
        let client = LingvanexClient.stubbed(StubTransport(data: body))

        let legacyOutcome: [Language]? = await withCheckedContinuation { continuation in
            api.getLanguages(nil) { languages, _ in
                continuation.resume(returning: languages)
            }
        }
        let modern = try await client.languages()

        #expect(legacyOutcome == modern)
    }

    @Test("A failure now arrives as an error instead of nil, nil")
    func failuresAreReported() async throws {
        let transport = StubTransport(data: try Fixture.data("translate_error_envelope"), statusCode: 401)
        let api = legacy(transport)

        let outcome = await translated(api)

        #expect(outcome.value == nil)
        #expect((outcome.error as? LingvanexError)?.label == "unauthorized")
    }

    @Test("Calling before start reports the mistake instead of crashing")
    func unconfiguredIsReported() async {
        let api = LingvanexAPI()

        let outcome = await translated(api)

        #expect(outcome.value == nil)
        #expect((outcome.error as? LingvanexError)?.label == "notConfigured")
    }

    @Test("A target language that is not a code is rejected before the request")
    func malformedTargetIsRejected() async throws {
        let transport = StubTransport(data: try Fixture.data("translate_success"))
        let api = legacy(transport)

        let outcome: Error? = await withCheckedContinuation { continuation in
            api.translate("en_GB", "not-a-code", "Hello") { _, error in
                continuation.resume(returning: error)
            }
        }

        #expect((outcome as? LingvanexError)?.label == "invalidLanguageCode")
        #expect(transport.requests.isEmpty)
    }

    @Test("The renamed model properties still read")
    func deprecatedPropertiesStillWork() async throws {
        let api = legacy(StubTransport(data: try Fixture.data("translate_with_transliteration")))

        let outcome = await translated(api)
        let translation = try #require(outcome.value)

        #expect(translation.result == "Привет")
        #expect(translation.from == "en_GB")
        #expect(translation.cacheUse == 0)
        #expect(translation.targetTransliteration == "Privet")
    }
}
