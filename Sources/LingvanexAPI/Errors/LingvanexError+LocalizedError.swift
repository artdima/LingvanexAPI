import Foundation

extension LingvanexError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "The Lingvanex client has no API key."
        case .invalidURL:
            return "The Lingvanex endpoint address is not a valid URL."
        case let .transport(underlying):
            return underlying.localizedDescription
        case let .unauthorized(message):
            return message ?? "The Lingvanex API key was rejected."
        case let .rateLimited(_, message):
            return message ?? "The Lingvanex request limit is exhausted."
        case let .server(status, message):
            return message ?? "Lingvanex responded with status \(status)."
        case let .decoding(underlying, _):
            return "The Lingvanex response could not be read: \(underlying.readableReason)"
        case .emptyResponse:
            return "Lingvanex returned an empty response."
        }
    }

    public var failureReason: String? {
        switch self {
        case .notConfigured, .invalidURL:
            return "The client is not set up correctly."
        case .transport:
            return "The request did not reach the service."
        case .unauthorized:
            return "The service refused the credentials."
        case .rateLimited:
            return "The account has no quota left for now."
        case let .server(status, _):
            return "The service answered with status \(status)."
        case let .decoding(_, rawBody):
            return rawBody.map { "The response began with: \($0)" }
        case .emptyResponse:
            return "The service answered with no content."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .notConfigured:
            return "Call start(with:) with a key from https://lingvanex.com/account before translating."
        case .unauthorized:
            return "Check the API key in your Lingvanex account."
        case let .rateLimited(retryAfter, _):
            guard let retryAfter else {
                return "Wait before sending further requests."
            }
            return "Retry in \(Int(retryAfter.rounded())) seconds."
        case .transport:
            return "Check the network connection and try again."
        case .decoding:
            return "The service contract may have changed; update the client."
        case .invalidURL, .server, .emptyResponse:
            return nil
        }
    }
}

private extension DecodingError {

    var readableReason: String {
        switch self {
        case let .keyNotFound(key, context):
            return "the field \"\(key.stringValue)\" is missing\(context.pathSuffix)"
        case let .valueNotFound(_, context):
            return "a required value is null\(context.pathSuffix)"
        case let .typeMismatch(type, context):
            return "expected \(type)\(context.pathSuffix)"
        case let .dataCorrupted(context):
            return "the body is not valid JSON\(context.pathSuffix)"
        @unknown default:
            return localizedDescription
        }
    }
}

private extension DecodingError.Context {

    var pathSuffix: String {
        let path = codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty ? "" : " at \(path)"
    }
}
