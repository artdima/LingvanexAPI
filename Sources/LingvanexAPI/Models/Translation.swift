import Foundation

/// The result of a translation request.
public struct Translation: Decodable, Equatable {

    /// The translation, in the same shape as the input: a string in, a string out.
    public let output: TranslationOutput

    /// The text that was sent for translation.
    public let source: TranslationOutput?

    /// The language the service detected. With auto-detection this is how the caller learns it.
    public let detectedSourceLanguage: LanguageCode?

    /// Number of characters served from the Lingvanex cache.
    public let charactersFromCache: Int?

    /// Present only when the request asked for transliteration.
    public let transliteration: Transliteration?

    /// The translation when a single string was sent.
    public var text: String? { output.text }

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

        output = try container.decode(TranslationOutput.self, forKey: .result)
        source = try container.decodeIfPresent(TranslationOutput.self, forKey: .source)
        charactersFromCache = try container.decodeIfPresent(Int.self, forKey: .charactersFromCache)

        // A code the client does not recognise is not worth failing the whole translation over.
        let reportedLanguage = try container.decodeIfPresent(String.self, forKey: .detectedSourceLanguage)
        detectedSourceLanguage = reportedLanguage.flatMap(LanguageCode.init(rawValue:))

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
