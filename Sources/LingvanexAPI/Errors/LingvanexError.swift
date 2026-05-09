import Foundation

/// Every way a Lingvanex call can fail.
public enum LingvanexError: Error {

    /// The client has no API key.
    case notConfigured

    /// A language code was not in `language_COUNTRY` form.
    case invalidLanguageCode(String)

    /// The endpoint could not be assembled from the configured base address.
    case invalidURL

    /// The request body could not be encoded.
    case encoding(underlying: Error)

    /// The request never reached the service: no connection, timeout, unreachable host.
    case transport(underlying: Error)

    /// The call was cancelled by its caller.
    case cancelled

    /// The key was rejected (401, 403).
    case unauthorized(message: String?)

    /// The quota or rate limit is exhausted (429).
    case rateLimited(retryAfter: TimeInterval?, message: String?)

    /// The service reported a failure, either by status code or in the `err` field of a 200 response.
    case server(status: Int, message: String?)

    /// The body did not match the expected shape. `rawBody` is truncated and kept for diagnostics.
    case decoding(underlying: DecodingError, rawBody: String?)

    /// A successful status with nothing to decode.
    case emptyResponse
}
