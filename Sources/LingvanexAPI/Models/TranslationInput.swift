import Foundation

/// What to translate. The service accepts a single string or an array of them,
/// and translating a list in one call costs one request instead of N.
public enum TranslationInput: Equatable, Sendable, ExpressibleByStringLiteral, ExpressibleByArrayLiteral {

    case text(String)
    case batch([String])

    public var isEmpty: Bool {
        switch self {
        case let .text(value): return value.isEmpty
        case let .batch(values): return values.isEmpty
        }
    }

    public init(stringLiteral value: StringLiteralType) {
        self = .text(value)
    }

    public init(arrayLiteral elements: String...) {
        self = .batch(elements)
    }
}

extension TranslationInput: Encodable {

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .text(value): try container.encode(value)
        case let .batch(values): try container.encode(values)
        }
    }
}

/// The translated counterpart of the input: a string in, a string out; a list in, a list out.
public enum TranslationOutput: Equatable, Sendable {

    case text(String)
    case batch([String])

    /// The translation when a single string was sent.
    public var text: String? {
        guard case let .text(value) = self else { return nil }
        return value
    }

    /// The translations when a list was sent.
    public var batch: [String]? {
        guard case let .batch(values) = self else { return nil }
        return values
    }

    /// Every translated string, whichever shape was returned.
    public var values: [String] {
        switch self {
        case let .text(value): return [value]
        case let .batch(values): return values
        }
    }
}

extension TranslationOutput: Decodable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .text(value)
            return
        }
        self = .batch(try container.decode([String].self))
    }
}
