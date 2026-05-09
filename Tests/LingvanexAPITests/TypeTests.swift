import Foundation
import Testing
@testable import LingvanexAPI

@Suite("Language code")
struct LanguageCodeTests {

    @Test("Well-formed codes are accepted", arguments: ["en_GB", "ru_RU", "es_ES", "zh-Hans_CN", "pt_BR"])
    func acceptsWellFormedCodes(value: String) {
        #expect(LanguageCode(rawValue: value)?.rawValue == value)
    }

    @Test(
        "Malformed codes are rejected",
        arguments: ["en", "EN_gb", "en-GB", "", "_GB", "en_", "en_gb", "en_GB_extra", "1_GB"]
    )
    func rejectsMalformedCodes(value: String) {
        #expect(LanguageCode(rawValue: value) == nil)
    }

    @Test("A code splits into its language and country")
    func codeExposesItsParts() {
        #expect(LanguageCode.enGB.language == "en")
        #expect(LanguageCode.enGB.country == "GB")
        #expect(LanguageCode.zhHansCN.language == "zh-Hans")
        #expect(LanguageCode.zhHansCN.country == "CN")
    }

    @Test("A code encodes and decodes as a plain string")
    func codeRoundTrips() throws {
        let encoded = try JSONEncoder().encode(["code": LanguageCode.ruRU])
        #expect(String(decoding: encoded, as: UTF8.self).contains("\"ru_RU\""))

        let decoded = try JSONDecoder().decode([String: LanguageCode].self, from: encoded)
        #expect(decoded["code"] == .ruRU)
    }

    @Test("Decoding a malformed code fails rather than producing a broken value")
    func decodingRejectsMalformedCodes() {
        let body = Data(#"{"code":"nonsense"}"#.utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([String: LanguageCode].self, from: body)
        }
    }
}

@Suite("Translation input and output")
struct TranslationInputTests {

    @Test("A single string encodes as a string")
    func textEncodesAsString() throws {
        let encoded = try JSONEncoder().encode(["data": TranslationInput.text("Hello")])

        #expect(String(decoding: encoded, as: UTF8.self) == #"{"data":"Hello"}"#)
    }

    @Test("A batch encodes as an array")
    func batchEncodesAsArray() throws {
        let encoded = try JSONEncoder().encode(["data": TranslationInput.batch(["Hello", "Bye"])])

        #expect(String(decoding: encoded, as: UTF8.self) == #"{"data":["Hello","Bye"]}"#)
    }

    @Test("A string literal is a single input and an array literal is a batch")
    func literalsBuildTheRightCase() {
        let single: TranslationInput = "Hello"
        let many: TranslationInput = ["Hello", "Bye"]

        #expect(single == .text("Hello"))
        #expect(many == .batch(["Hello", "Bye"]))
    }

    @Test("A string result decodes as a single output")
    func stringResultDecodes() throws {
        let decoded = try JSONDecoder().decode([String: TranslationOutput].self, from: Data(#"{"r":"Привет"}"#.utf8))

        #expect(decoded["r"] == .text("Привет"))
        #expect(decoded["r"]?.text == "Привет")
        #expect(decoded["r"]?.batch == nil)
    }

    @Test("An array result decodes as a batch")
    func arrayResultDecodes() throws {
        let body = Data(#"{"r":["Привет","Пока"]}"#.utf8)
        let decoded = try JSONDecoder().decode([String: TranslationOutput].self, from: body)

        #expect(decoded["r"] == .batch(["Привет", "Пока"]))
        #expect(decoded["r"]?.text == nil)
        #expect(decoded["r"]?.values == ["Привет", "Пока"])
    }
}

@Suite("Cancellation")
struct CancellationTests {

    @Test("A cancelled task is not sent at all")
    func cancelledTaskIsNotSent() async throws {
        let transport = StubTransport(data: try Fixture.data("translate_success"))
        let client = LingvanexClient.stubbed(transport)

        let task = Task<Translation, Error> {
            var spins = 0
            while !Task.isCancelled, spins < 10_000 {
                await Task.yield()
                spins += 1
            }
            return try await client.translate("Hello", to: .ruRU)
        }
        task.cancel()

        let error = await failure(of: task)
        #expect((error as? LingvanexError)?.label == "cancelled")
        #expect(transport.requests.isEmpty)
    }

    @Test("Cancelling an in-flight call surfaces as a cancellation, not a transport failure")
    func inFlightCancellationIsReported() async throws {
        let client = LingvanexClient.stubbed(HangingTransport())

        let task = Task<Translation, Error> {
            try await client.translate("Hello", to: .ruRU)
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()

        let error = await failure(of: task)
        #expect((error as? LingvanexError)?.label == "cancelled")
    }

    private func failure<Value>(of task: Task<Value, Error>) async -> Error? {
        do {
            _ = try await task.value
            return nil
        } catch {
            return error
        }
    }
}
