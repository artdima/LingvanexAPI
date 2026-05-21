import Foundation

/// Wraps the API key so it cannot be printed by accident.
///
/// Interpolating this type into a log line, a crash report or an error message
/// yields a mask; the key itself is only reachable inside the library.
public struct APIKey: Hashable, Sendable, ExpressibleByStringLiteral,
                      CustomStringConvertible, CustomDebugStringConvertible {

    let value: String

    public var description: String { masked }
    public var debugDescription: String { masked }

    public var isEmpty: Bool { value.isEmpty }

    public init(_ value: String) {
        self.value = value
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }

    private var masked: String {
        guard value.count > 12 else { return "***" }
        return "\(value.prefix(4))…\(value.suffix(4))"
    }
}
