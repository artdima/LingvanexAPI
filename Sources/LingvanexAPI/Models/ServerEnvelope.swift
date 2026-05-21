import Foundation

/// Both endpoints wrap their answer in the same shape: an optional `err` next to the payload.
/// A non-empty `err` means failure even when the status code says 200.
struct ServerEnvelope: Decodable, Sendable {
    let err: String?
}

/// `getLanguages` returns its payload under `result`; `translate` returns it flattened at the top level.
struct LanguageListResponse: Decodable, Sendable {
    let result: [Language]
}
