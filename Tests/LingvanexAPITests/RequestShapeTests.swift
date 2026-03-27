import Foundation
import Testing
@testable import LingvanexAPI

@Suite("The requests the client builds")
struct RequestShapeTests {

    private func translateRequest(
        from: String = "en_GB",
        to: String = "ru_RU",
        text: String = "Hello",
        configuration: LingvanexConfiguration? = nil
    ) async throws -> URLRequest {
        let transport = StubTransport(data: try Fixture.data("translate_with_transliteration"))
        var settings = configuration ?? LingvanexConfiguration()
        settings.apiKey = "test-key"
        let api = LingvanexAPI(configuration: settings, transport: transport)
        _ = await api.translated(from: from, to: to, text: text)
        return try #require(transport.lastRequest)
    }

    private func languagesRequest(displayLanguage: String? = nil) async throws -> URLRequest {
        let transport = StubTransport(data: try Fixture.data("languages_success"))
        let api = LingvanexAPI.stubbed(transport)
        _ = await api.languageList(displayLanguage: displayLanguage)
        return try #require(transport.lastRequest)
    }

    private func translateBody() async throws -> [String: Any] {
        let request = try await translateRequest()
        let body = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: body)
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
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        #expect(request.httpBody == nil)
    }

    @Test("The display language reaches the query only when it is given")
    func displayLanguageIsOptionalInTheQuery() async throws {
        let withoutCode = try await languagesRequest()
        let withCode = try await languagesRequest(displayLanguage: "ru_RU")

        #expect(withoutCode.url?.query?.contains("code=") == false)
        #expect(withCode.url?.query?.contains("code=ru_RU") == true)
    }

    @Test("A configured base address is used instead of the built-in one")
    func baseURLIsConfigurable() async throws {
        var configuration = LingvanexConfiguration()
        configuration.baseURL = try #require(URL(string: "https://lingvanex.internal/api/v3"))

        let request = try await translateRequest(configuration: configuration)

        #expect(request.url?.absoluteString == "https://lingvanex.internal/api/v3/translate")
    }

    // MARK: - Headers

    @Test("Every request announces the content type it accepts")
    func requestsSendAcceptHeader() async throws {
        let translate = try await translateRequest()
        let languages = try await languagesRequest()

        #expect(translate.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(languages.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test("Every request identifies the client and its version")
    func requestsSendUserAgent() async throws {
        let translate = try await translateRequest()
        let languages = try await languagesRequest()

        #expect(translate.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("LingvanexAPI-Swift/") == true)
        #expect(languages.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("LingvanexAPI-Swift/") == true)
    }

    @Test("The configured timeout reaches the request")
    func timeoutIsApplied() async throws {
        var configuration = LingvanexConfiguration()
        configuration.timeout = 7

        let request = try await translateRequest(configuration: configuration)

        #expect(request.timeoutInterval == 7)
    }

    // MARK: - Body

    @Test("Translate sends the caller's arguments in the body")
    func translateBodyCarriesTheArguments() async throws {
        let body = try await translateBody()

        #expect(body["from"] as? String == "en_GB")
        #expect(body["to"] as? String == "ru_RU")
        #expect(body["data"] as? String == "Hello")
        #expect(body["platform"] as? String == "api")
    }

    @Test("The body is compact, so no padding travels over the wire")
    func translateBodyIsCompact() async throws {
        let request = try await translateRequest()
        let body = try #require(request.httpBody)

        #expect(String(decoding: body, as: UTF8.self).contains("\n") == false)
    }

    @Test("Translate still does not ask for transliteration or an HTML mode")
    func translateDoesNotYetSendTheNewerOptions() async throws {
        let body = try await translateBody()

        #expect(body.keys.contains("enableTransliteration") == false)
        #expect(body.keys.contains("translateMode") == false)
    }

    @Test("A request body model omits an absent source language rather than sending null")
    func absentSourceLanguageIsOmitted() throws {
        let request = TranslateRequest(from: nil, to: "ru_RU", data: "Hello", platform: "api")

        let encoded = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: encoded)
        let body = try #require(object as? [String: Any])

        #expect(body.keys.contains("from") == false)
        #expect(body["to"] as? String == "ru_RU")
    }
}
