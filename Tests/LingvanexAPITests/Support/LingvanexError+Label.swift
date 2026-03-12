import Foundation
@testable import LingvanexAPI

extension LingvanexError {

    /// Case name only, so a test can assert which failure happened without unwrapping payloads.
    var label: String {
        switch self {
        case .notConfigured: return "notConfigured"
        case .invalidURL: return "invalidURL"
        case .transport: return "transport"
        case .unauthorized: return "unauthorized"
        case .rateLimited: return "rateLimited"
        case .server: return "server"
        case .decoding: return "decoding"
        case .emptyResponse: return "emptyResponse"
        }
    }
}
