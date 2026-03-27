import Foundation

/// Everything the client needs besides the call itself.
/// Internal for now; it becomes the public entry point when the client stops being a singleton.
struct LingvanexConfiguration {

    static var defaultBaseURL: URL {
        guard let url = URL(string: "https://api-b2b.backenster.com/b1/api/v3") else {
            preconditionFailure("The built-in Lingvanex base address is not a valid URL")
        }
        return url
    }

    static var defaultUserAgent: String {
        "LingvanexAPI-Swift/\(LingvanexAPIVersion.current) (\(LingvanexAPIVersion.platform))"
    }

    var apiKey: String?

    /// Configurable so tests, a staging deployment and an on-premise install can all be addressed.
    var baseURL: URL = LingvanexConfiguration.defaultBaseURL

    /// A minute of waiting is unusable on a phone; twenty seconds is a real timeout.
    var timeout: TimeInterval = 20
    var resourceTimeout: TimeInterval = 60

    /// Wait for a connection to come back instead of failing the moment it drops.
    var waitsForConnectivity: Bool = true

    var retryPolicy: RetryPolicy = .default
    var userAgent: String = LingvanexConfiguration.defaultUserAgent

    /// Off unless the host supplies a sink: a library should not decide where logs go.
    var logger: ((String) -> Void)?

    var sessionConfiguration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = waitsForConnectivity
        return configuration
    }
}

enum LingvanexAPIVersion {

    /// Kept in step with the podspec and the release tag.
    static let current = "0.1.0"

    static var platform: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(watchOS)
        return "watchOS"
        #elseif os(visionOS)
        return "visionOS"
        #elseif os(Linux)
        return "Linux"
        #else
        return "unknown"
        #endif
    }
}
