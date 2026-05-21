import Foundation

/// Body of a `translate` call. Typed rather than a dictionary, so a mistyped key
/// is a compile error instead of a puzzling answer from the service.
struct TranslateRequest: Encodable, Equatable, Sendable {

    let from: LanguageCode?
    let to: LanguageCode
    let data: TranslationInput
    let platform: String
    let options: TranslationOptions

    private enum CodingKeys: String, CodingKey {
        case from
        case to
        case data
        case platform
        case translateMode
        case enableTransliteration
    }

    /// Only the switches that are actually on are sent, so a default request stays minimal.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(from, forKey: .from)
        try container.encode(to, forKey: .to)
        try container.encode(data, forKey: .data)
        try container.encode(platform, forKey: .platform)

        if options.mode != .plain {
            try container.encode(options.mode.rawValue, forKey: .translateMode)
        }
        if options.includeTransliteration {
            try container.encode(true, forKey: .enableTransliteration)
        }
    }
}
