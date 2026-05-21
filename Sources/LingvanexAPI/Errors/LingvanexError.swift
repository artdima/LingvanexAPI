import Foundation

/// Every way a Lingvanex call can fail.
public enum LingvanexError: Error, Sendable {

    /// The client has no API key.
    case notConfigured

    /// A language code was not in `language_COUNTRY` form.
    case invalidLanguageCode(String)

    /// The endpoint could not be assembled from the configured base address.
    case invalidURL

    /// The request body could not be encoded.
    case encoding(reason: String)

    /// The request never reached the service: no connection, timeout, unreachable host.
    case transport(underlying: any Error & Sendable)

    /// The call was cancelled by its caller.
    case cancelled

    /// The key was rejected (401, 403).
    case unauthorized(message: String?)

    /// The quota or rate limit is exhausted (429).
    case rateLimited(retryAfter: TimeInterval?, message: String?)

    /// The service reported a failure, either by status code or in the `err` field of a 200 response.
    case server(status: Int, message: String?)

    /// The body did not match the expected shape. `rawBody` is truncated and kept for diagnostics.
    case decoding(DecodingFailure, rawBody: String?)

    /// A successful status with nothing to decode.
    case emptyResponse
}

/// What went wrong while reading a response, reduced to the parts that answer
/// "which field, and why" — and that can safely cross a task boundary.
///
/// `DecodingError` itself carries an untyped underlying error, so it is not `Sendable`
/// and cannot travel with the failure. Everything worth reading from it is here.
public struct DecodingFailure: Error, Sendable, Equatable {

    public enum Kind: String, Sendable {
        case keyNotFound
        case valueNotFound
        case typeMismatch
        case dataCorrupted
        case unknown
    }

    /// What kind of mismatch it was.
    public let kind: Kind

    /// The field that was missing or wrong, when the decoder named one.
    public let field: String?

    /// Where in the response it happened, for example `result.0.full_code`.
    public let codingPath: [String]

    /// A sentence describing the mismatch, suitable for a log or a bug report.
    public let reason: String

    init(_ error: DecodingError) {
        switch error {
        case let .keyNotFound(key, context):
            kind = .keyNotFound
            field = key.stringValue
            codingPath = context.codingPath.map(\.stringValue)
            reason = "the field \"\(key.stringValue)\" is missing\(Self.suffix(for: context))"

        case let .valueNotFound(_, context):
            kind = .valueNotFound
            field = context.codingPath.last?.stringValue
            codingPath = context.codingPath.map(\.stringValue)
            reason = "a required value is null\(Self.suffix(for: context))"

        case let .typeMismatch(type, context):
            kind = .typeMismatch
            field = context.codingPath.last?.stringValue
            codingPath = context.codingPath.map(\.stringValue)
            reason = "expected \(type)\(Self.suffix(for: context))"

        case let .dataCorrupted(context):
            kind = .dataCorrupted
            field = context.codingPath.last?.stringValue
            codingPath = context.codingPath.map(\.stringValue)
            reason = "the body is not valid JSON\(Self.suffix(for: context))"

        @unknown default:
            kind = .unknown
            field = nil
            codingPath = []
            reason = error.localizedDescription
        }
    }

    private static func suffix(for context: DecodingError.Context) -> String {
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty ? "" : " at \(path)"
    }
}

/// An error from below the client that is not a `URLError`, reduced to its description
/// so it can travel with the failure.
public struct TransportFailure: Error, Sendable, Equatable, CustomStringConvertible {

    public let description: String

    init(_ error: any Error) {
        description = error.localizedDescription
    }
}
