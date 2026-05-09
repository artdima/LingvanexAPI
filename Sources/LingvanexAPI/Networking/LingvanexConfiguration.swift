import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Everything the client needs besides the call itself.
public struct LingvanexConfiguration {

    public static var defaultBaseURL: URL {
        guard let url = URL(string: "https://api-b2b.backenster.com/b1/api/v3") else {
            preconditionFailure("The built-in Lingvanex base address is not a valid URL")
        }
        return url
    }

    public static var defaultUserAgent: String {
        "LingvanexAPI-Swift/\(LingvanexAPIVersion.current) (\(LingvanexAPIVersion.platform))"
    }

    public var apiKey: APIKey

    /// Configurable so tests, a staging deployment and an on-premise install can all be addressed.
    public var baseURL: URL

    /// A minute of waiting is unusable on a phone; twenty seconds is a real timeout.
    public var timeout: TimeInterval

    public var resourceTimeout: TimeInterval

    /// Wait for a connection to come back instead of failing the moment it drops.
    public var waitsForConnectivity: Bool

    public var retryPolicy: RetryPolicy

    public var userAgent: String

    /// Off unless the host supplies a sink: a library should not decide where logs go.
    public var logger: ((String) -> Void)?

    /// Replaces the whole networking stack. Useful for tests and for hosts with their own.
    public var transport: HTTPTransport?

    public init(
        apiKey: APIKey,
        baseURL: URL = LingvanexConfiguration.defaultBaseURL,
        timeout: TimeInterval = 20,
        resourceTimeout: TimeInterval = 60,
        waitsForConnectivity: Bool = true,
        retryPolicy: RetryPolicy = .default,
        userAgent: String = LingvanexConfiguration.defaultUserAgent,
        logger: ((String) -> Void)? = nil,
        transport: HTTPTransport? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.timeout = timeout
        self.resourceTimeout = resourceTimeout
        self.waitsForConnectivity = waitsForConnectivity
        self.retryPolicy = retryPolicy
        self.userAgent = userAgent
        self.logger = logger
        self.transport = transport
    }

    var sessionConfiguration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = waitsForConnectivity
        return configuration
    }
}

public enum LingvanexAPIVersion {

    /// Kept in step with the podspec and the release tag.
    public static let current = "1.0.0"

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
