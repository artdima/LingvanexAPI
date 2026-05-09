import Foundation
import Testing
@testable import LingvanexAPI

@Suite("The requests the client builds")
struct RequestShapeTests {

    private func translateRequest(
        _ input: TranslationInput = .text("Hello"),
        from source: LanguageCode? = .enGB,
        to target: LanguageCode = .ruRU,
        options: TranslationOptions = .default,
        configure: (inout LingvanexConfiguration) -> Void = { _ in }
    ) async throws -> URLRequest {
        let transport = StubTransport(data: try Fixture.data("translate_with_transliteration"))
        let client = LingvanexClient.stubbed(transport, configure: configure)
        _ = try await client.translate(input, from: source, to: target, options: options)
        return try #require(transport.lastRequest)
    }

    private func languagesRequest(displayLanguage: LanguageCode? = nil) async throws -> URLRequest {
        let transport = StubTransport(data: try Fixture.data("languages_success"))
        let client = LingvanexClient.stubbed(transport)
        _ = try await client.languages(displayLanguage: displayLanguage)
        return try #require(transport.lastRequest)
    }

    private func body(of request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    // MARK: - Addressing

    @Test("Translate posts to the v3 endpoint with the bearer token")
    func translateEndpointAndAuthorization() async throws {
        let request = try await translateRequest()

        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api-b2b.backenster.com/b1/api/v3/translate")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("The language list is a GET carrying the platform")
    func languagesEndpointAndAuthorization() async throws {
        let request = try await languagesRequest()

        #expect(request.httpMethod == "GET")
        #expect(request.url?.path == "/b1/api/v3/getLanguages")
        #expect(request.url?.query?.contains("platform=api") == true)
        #expect(request.httpBody == nil)
    }

    @Test("The display language reaches the query only when it is given")
    func displayLanguageIsOptionalInTheQuery() async throws {
        let withoutCode = try await languagesRequest()
        let withCode = try await languagesRequest(displayLanguage: .ruRU)

        #expect(withoutCode.url?.query?.contains("code=") == false)
        #expect(withCode.url?.query?.contains("code=ru_RU") == true)
    }

    @Test("A configured base address is used instead of the built-in one")
    func baseURLIsConfigurable() async throws {
        let custom = try #require(URL(string: "https://lingvanex.internal/api/v3"))

        let request = try await translateRequest { $0.baseURL = custom }

        #expect(request.url?.absoluteString == "https://lingvanex.internal/api/v3/translate")
    }

    // MARK: - Headers

    @Test("Every request announces the content type it accepts and identifies the client")
    func requestsCarryStandardHeaders() async throws {
        let translate = try await translateRequest()
        let languages = try await languagesRequest()

        #expect(translate.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(languages.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(translate.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("LingvanexAPI-Swift/") == true)
        #expect(languages.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("LingvanexAPI-Swift/") == true)
    }

    @Test("The configured timeout reaches the request")
    func timeoutIsApplied() async throws {
        let request = try await translateRequest { $0.timeout = 7 }

        #expect(request.timeoutInterval == 7)
    }

    // MARK: - Body

    @Test("Translate sends the caller's arguments in the body")
    func translateBodyCarriesTheArguments() async throws {
        let request = try await translateRequest()
        let body = try body(of: request)

        #expect(body["from"] as? String == "en_GB")
        #expect(body["to"] as? String == "ru_RU")
        #expect(body["data"] as? String == "Hello")
        #expect(body["platform"] as? String == "api")
    }

    @Test("The body is compact, so no padding travels over the wire")
    func translateBodyIsCompact() async throws {
        let request = try await translateRequest()
        let data = try #require(request.httpBody)

        #expect(String(decoding: data, as: UTF8.self).contains("\n") == false)
    }

    @Test("Auto-detection omits the source language rather than sending null")
    func autoDetectionOmitsSourceLanguage() async throws {
        let request = try await translateRequest(from: nil)
        let body = try body(of: request)

        #expect(body.keys.contains("from") == false)
        #expect(body["to"] as? String == "ru_RU")
    }

    @Test("A batch is sent as an array")
    func batchIsSentAsAnArray() async throws {
        let request = try await translateRequest(.batch(["Hello", "Goodbye"]))
        let body = try body(of: request)

        #expect(body["data"] as? [String] == ["Hello", "Goodbye"])
    }

    @Test("Default options add nothing to the body")
    func defaultOptionsAreNotSent() async throws {
        let request = try await translateRequest()
        let body = try body(of: request)

        #expect(body.keys.contains("translateMode") == false)
        #expect(body.keys.contains("enableTransliteration") == false)
    }

    @Test("HTML mode and transliteration are sent when asked for")
    func optionsReachTheBody() async throws {
        let options = TranslationOptions(mode: .html, includeTransliteration: true)
        let request = try await translateRequest(options: options)
        let body = try body(of: request)

        #expect(body["translateMode"] as? String == "html")
        #expect(body["enableTransliteration"] as? Bool == true)
    }
}
