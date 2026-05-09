import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Traces requests through a sink the host supplies. Off unless one is configured:
/// a library has no business choosing where an application's logs go.
public struct LoggingTransport: HTTPTransport {

    private let base: HTTPTransport
    private let sink: (String) -> Void

    public init(wrapping base: HTTPTransport, sink: @escaping (String) -> Void) {
        self.base = base
        self.sink = sink
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "?"
        sink("→ \(method) \(url) \(Self.describeHeaders(of: request))")

        do {
            let (data, response) = try await base.send(request)
            sink("← \(response.statusCode), \(data.count) bytes")
            return (data, response)
        } catch {
            sink("← failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// The key must never reach a log file, a crash report or a support ticket.
    static func redactAuthorization(_ value: String) -> String {
        let prefix = "Bearer "
        let token = value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : value
        guard token.count > 12 else { return "Bearer ***" }
        return "Bearer \(token.prefix(4))…\(token.suffix(4))"
    }

    private static func describeHeaders(of request: URLRequest) -> String {
        let headers = (request.allHTTPHeaderFields ?? [:])
            .map { name, value -> String in
                name.lowercased() == "authorization" ? "\(name): \(redactAuthorization(value))" : "\(name): \(value)"
            }
            .sorted()
        return "[\(headers.joined(separator: "; "))]"
    }
}
