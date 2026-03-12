import Foundation

/// The result of a translation request.
public struct Translation: Decodable, Equatable {

    /// The translated text.
    public let result: String

    /// The text that was sent for translation.
    public let source: String?

    /// The language the service detected, in `language_COUNTRY` form.
    /// Present when the service reports it; with auto-detection this is how the caller learns the source language.
    public let detectedSourceLanguage: String?

    /// Number of characters served from the Lingvanex cache.
    public let charactersFromCache: Int?

    /// Present only when the request asked for transliteration.
    public let transliteration: Transliteration?

    private enum CodingKeys: String, CodingKey {
        case result
        case source
        case detectedSourceLanguage = "from"
        case charactersFromCache = "cacheUse"
        case sourceTransliteration
        case targetTransliteration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        result = try container.decode(String.self, forKey: .result)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        detectedSourceLanguage = try container.decodeIfPresent(String.self, forKey: .detectedSourceLanguage)
        charactersFromCache = try container.decodeIfPresent(Int.self, forKey: .charactersFromCache)

        let sourceForm = try container.decodeIfPresent(String.self, forKey: .sourceTransliteration)
        let targetForm = try container.decodeIfPresent(String.self, forKey: .targetTransliteration)
        transliteration = Transliteration(source: sourceForm, target: targetForm)
    }
}

/// Transliterated forms of the source and the translation.
public struct Transliteration: Equatable {

    public let source: String?
    public let target: String?

    init?(source: String?, target: String?) {
        guard source != nil || target != nil else { return nil }
        self.source = source
        self.target = target
    }
}
