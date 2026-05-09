import Foundation

/// Optional switches on a translation request.
public struct TranslationOptions: Equatable {

    /// How the service should treat the input.
    public enum Mode: String, Equatable {
        /// Plain text. The default.
        case plain
        /// Markup is preserved instead of being translated along with the text.
        case html
    }

    public static let `default` = TranslationOptions()

    public var mode: Mode

    /// Ask for the transliterated forms. They are absent from the response unless this is set.
    public var includeTransliteration: Bool

    public init(mode: Mode = .plain, includeTransliteration: Bool = false) {
        self.mode = mode
        self.includeTransliteration = includeTransliteration
    }
}
