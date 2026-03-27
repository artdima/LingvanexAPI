import Foundation

/// Body of a `translate` call. Typed rather than a dictionary, so a mistyped key
/// is a compile error instead of a puzzling answer from the service.
struct TranslateRequest: Encodable, Equatable {
    let from: String?
    let to: String
    let data: String
    let platform: String
}
