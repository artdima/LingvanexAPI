import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Traces requests through a sink the host supplies. Off unless one is configured:
/// a library has no business choosing where an application's logs go.
struct LoggingTransport: HTTPTransport {

    private let base: HTTPTransport
    private let sink: (String) -> Void

    init(wrapping base: HTTPTransport, sink: @escaping (String) -> Void) {
        self.base = base
        self.sink = sink
    }

    func send(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        sink("→ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?") \(Self.describeHeaders(of: request))")

        base.send(request) { data, response, error in
            if let error {
                sink("← failed: \(error.localizedDescription)")
            } else if let response = response as? HTTPURLResponse {
                sink("← \(response.statusCode), \(data?.count ?? 0) bytes")
            }
            completion(data, response, error)
        }
    }

    /// The key must never reach a log file, a crash report or a support ticket.
    static func redactAuthorization(_ value: String) -> String {
        let token = value.hasPrefix("Bearer ") ? String(value.dropFirst("Bearer ".count)) : value
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
