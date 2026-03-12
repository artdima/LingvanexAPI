import Foundation

public extension LingvanexAPI {

    @available(*, deprecated, renamed: "Translation")
    typealias Translate = Translation

    @available(*, deprecated, renamed: "Language")
    typealias Languages = Language

    @available(*, deprecated, renamed: "LanguageFeature")
    typealias Mode = LanguageFeature
}

public extension Translation {

    @available(*, deprecated, renamed: "detectedSourceLanguage")
    var from: String? { detectedSourceLanguage }

    @available(*, deprecated, renamed: "charactersFromCache")
    var cacheUse: Int? { charactersFromCache }

    @available(*, deprecated, message: "Use transliteration?.source")
    var sourceTransliteration: String? { transliteration?.source }

    @available(*, deprecated, message: "Use transliteration?.target")
    var targetTransliteration: String? { transliteration?.target }

    @available(*, deprecated, message: "A failure is now delivered as a LingvanexError instead of a field")
    var err: String? { nil }
}

public extension Language {

    @available(*, deprecated, renamed: "code")
    var name: String? { code }

    @available(*, deprecated, renamed: "localizedName")
    var codeName: String? { localizedName }

    @available(*, deprecated, renamed: "testWordForSynthesis")
    var testWordForSyntezis: String? { testWordForSynthesis }

    @available(*, deprecated, renamed: "features")
    var modes: [LanguageFeature] { features }
}

public extension LanguageFeature {

    @available(*, deprecated, renamed: "isEnabled")
    var value: Bool { isEnabled }

    @available(*, deprecated, renamed: "supportsBothGenders")
    var genders: Bool? { supportsBothGenders }
}
