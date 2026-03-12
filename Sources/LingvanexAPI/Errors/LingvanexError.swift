import Foundation

/// Every way a Lingvanex call can fail.
public enum LingvanexError: Error {

    /// `start(with:)` was never called, so there is no key to authenticate with.
    case notConfigured

    /// The endpoint could not be assembled from the configured base address.
    case invalidURL

    /// The request never reached the service: no connection, timeout, cancellation.
    case transport(underlying: Error)

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
