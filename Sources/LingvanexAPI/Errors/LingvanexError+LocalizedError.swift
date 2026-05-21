import Foundation

extension LingvanexError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "The Lingvanex client has no API key."
        case let .invalidLanguageCode(value):
            return "\"\(value)\" is not a language code in language_COUNTRY form."
        case .invalidURL:
            return "The Lingvanex endpoint address is not a valid URL."
        case .encoding:
            return "The Lingvanex request could not be encoded."
        case let .transport(underlying):
            return underlying.localizedDescription
        case .cancelled:
            return "The Lingvanex request was cancelled."
        case let .unauthorized(message):
            return message ?? "The Lingvanex API key was rejected."
        case let .rateLimited(_, message):
            return message ?? "The Lingvanex request limit is exhausted."
        case let .server(status, message):
            return message ?? "Lingvanex responded with status \(status)."
        case let .decoding(failure, _):
            return "The Lingvanex response could not be read: \(failure.reason)"
        case .emptyResponse:
            return "Lingvanex returned an empty response."
        }
    }

    public var failureReason: String? {
        switch self {
        case .notConfigured, .invalidURL:
            return "The client is not set up correctly."
        case .invalidLanguageCode:
            return "A language code looks like en_GB: lowercase language, uppercase country."
        case let .encoding(reason):
            return reason
        case .transport:
            return "The request did not reach the service."
        case .cancelled:
            return "The caller cancelled the request."
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
            return "Create the client with a key from https://lingvanex.com/account."
        case .invalidLanguageCode:
            return "Use one of the codes returned by languages(displayLanguage:)."
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
        case .invalidURL, .encoding, .cancelled, .server, .emptyResponse:
            return nil
        }
    }
}
