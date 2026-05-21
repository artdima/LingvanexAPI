import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A client for the Lingvanex Translation API.
///
/// ```swift
/// let client = LingvanexClient(apiKey: "…")
/// let translation = try await client.translate("Hello", to: .ruRU)
/// print(translation.text ?? "")
/// ```
///
/// The key is required to construct the client, so a client that is not configured
/// cannot exist. Cancelling the calling task cancels the request.
public struct LingvanexClient: Sendable {

    private let configuration: LingvanexConfiguration
    private let transport: HTTPTransport

    public init(configuration: LingvanexConfiguration) {
        self.configuration = configuration
        transport = configuration.transport ?? Self.makeTransport(for: configuration)
    }

    public init(apiKey: APIKey) {
        self.init(configuration: LingvanexConfiguration(apiKey: apiKey))
    }

    /// Translates text.
    ///
    /// - Parameters:
    ///   - input: A single string or a list of them. A list costs one request instead of N.
    ///   - source: The language to translate from. Omit it to let the service detect the language.
    ///   - target: The language to translate into.
    ///   - options: HTML mode and transliteration. Both are off by default.
    public func translate(
        _ input: TranslationInput,
        from source: LanguageCode? = nil,
        to target: LanguageCode,
        options: TranslationOptions = .default
    ) async throws -> Translation {
        let request = TranslateRequest(
            from: source,
            to: target,
            data: input,
            platform: Self.platform,
            options: options
        )
        let endpoint = try Endpoint.translate(request)
        return try await perform(endpoint)
    }

    /// The languages the service supports.
    ///
    /// - Parameter displayLanguage: The language the names are returned in. English by default.
    public func languages(displayLanguage: LanguageCode? = nil) async throws -> [Language] {
        let endpoint = Endpoint<LanguageListResponse>.languages(
            displayLanguage: displayLanguage,
            platform: Self.platform
        )
        return try await perform(endpoint).result
    }

    /// Every call goes through here: one place for building the request, validating the
    /// answer, decoding it and turning any failure into a LingvanexError.
    private func perform<Response: Decodable>(_ endpoint: Endpoint<Response>) async throws -> Response {
        let request = try RequestBuilder(configuration: configuration).makeRequest(for: endpoint)

        guard !Task.isCancelled else { throw LingvanexError.cancelled }

        let (data, response) = try await transport.send(request)
        let body = try ResponseValidator.validate(data: data, response: response)
        return try ResponseValidator.decode(Response.self, from: body)
    }

    private static let platform = "api"

    private static func makeTransport(for configuration: LingvanexConfiguration) -> HTTPTransport {
        let session = URLSessionTransport(configuration: configuration.sessionConfiguration)
        let retrying = RetryingTransport(wrapping: session, policy: configuration.retryPolicy)

        guard let logger = configuration.logger else {
            return retrying
        }
        return LoggingTransport(wrapping: retrying, sink: logger)
    }
}

public extension LingvanexClient {

    /// Convenience for the common case of translating one string.
    func translate(
        _ text: String,
        from source: LanguageCode? = nil,
        to target: LanguageCode,
        options: TranslationOptions = .default
    ) async throws -> Translation {
        try await translate(.text(text), from: source, to: target, options: options)
    }

    init(apiKey: String) {
        self.init(apiKey: APIKey(apiKey))
    }
}
