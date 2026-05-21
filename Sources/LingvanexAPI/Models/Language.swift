import Foundation

/// One language supported by the service.
public struct Language: Decodable, Equatable, Sendable {

    /// Language code in `language_COUNTRY` form, for example `en_GB`.
    public let fullCode: String

    /// Language code without the country part, for example `en`.
    public let code: String?

    /// English name of the language.
    public let englishName: String

    /// Name of the language in the display language requested for the call.
    public let localizedName: String?

    /// Relative path of the flag image, for example `static/flags/english`.
    public let flagPath: String?

    /// A word suitable for testing speech synthesis.
    public let testWordForSynthesis: String?

    /// What the service can do for this language.
    public let features: [LanguageFeature]

    private enum CodingKeys: String, CodingKey {
        case fullCode = "full_code"
        case code = "name"
        case englishName
        case localizedName = "codeName"
        case flagPath
        case testWordForSynthesis = "testWordForSyntezis"
        case features = "modes"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        fullCode = try container.decode(String.self, forKey: .fullCode)
        englishName = try container.decode(String.self, forKey: .englishName)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        localizedName = try container.decodeIfPresent(String.self, forKey: .localizedName)
        flagPath = try container.decodeIfPresent(String.self, forKey: .flagPath)
        testWordForSynthesis = try container.decodeIfPresent(String.self, forKey: .testWordForSynthesis)
        features = try container.decodeIfPresent([LanguageFeature].self, forKey: .features) ?? []
    }
}

/// A capability the service offers for a language.
public struct LanguageFeature: Decodable, Equatable, Sendable {

    /// Name of the capability, for example `Translation` or `Speech synthesis`.
    public let name: String

    /// Whether the capability is currently on.
    public let isEnabled: Bool

    /// Whether both genders can be synthesised. Reported for speech synthesis only.
    public let supportsBothGenders: Bool?

    private enum CodingKeys: String, CodingKey {
        case name
        case isEnabled = "value"
        case supportsBothGenders = "genders"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        supportsBothGenders = try container.decodeIfPresent(Bool.self, forKey: .supportsBothGenders)
    }
}
