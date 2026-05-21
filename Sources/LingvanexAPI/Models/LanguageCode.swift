import Foundation

/// A Lingvanex language code in `language_COUNTRY` form, for example `en_GB`.
///
/// Having a type here is what stops the commonest mistake in a translation API:
/// two `String` arguments in a row that the compiler is happy to see swapped.
public struct LanguageCode: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {

    public let rawValue: String

    public var description: String { rawValue }

    /// The language part, for example `en` in `en_GB`.
    public var language: String {
        String(rawValue.prefix(while: { $0 != "_" }))
    }

    /// The country part, for example `GB` in `en_GB`.
    public var country: String {
        String(rawValue.drop(while: { $0 != "_" }).dropFirst())
    }

    public init?(rawValue: String) {
        guard Self.isWellFormed(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    private init(unchecked rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard let code = LanguageCode(rawValue: value) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "\"\(value)\" is not a language_COUNTRY code"
                )
            )
        }
        self = code
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// Lowercase language, uppercase country, exactly one separator.
    /// Deliberately permissive about script subtags such as `zh-Hans_CN`.
    private static func isWellFormed(_ value: String) -> Bool {
        let parts = value.split(separator: "_", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }

        let language = parts[0]
        let country = parts[1]
        guard !language.isEmpty, !country.isEmpty else { return false }

        guard language.allSatisfy({ $0.isLetter || $0 == "-" }),
              language.prefix(2).allSatisfy({ $0.isLowercase }) else { return false }

        return country.allSatisfy { ($0.isLetter && $0.isUppercase) || $0.isNumber }
    }
}

public extension LanguageCode {
    static let enGB = LanguageCode(unchecked: "en_GB")
    static let enUS = LanguageCode(unchecked: "en_US")
    static let ruRU = LanguageCode(unchecked: "ru_RU")
    static let deDE = LanguageCode(unchecked: "de_DE")
    static let esES = LanguageCode(unchecked: "es_ES")
    static let frFR = LanguageCode(unchecked: "fr_FR")
    static let itIT = LanguageCode(unchecked: "it_IT")
    static let ptPT = LanguageCode(unchecked: "pt_PT")
    static let jaJP = LanguageCode(unchecked: "ja_JP")
    static let zhHansCN = LanguageCode(unchecked: "zh-Hans_CN")
}
