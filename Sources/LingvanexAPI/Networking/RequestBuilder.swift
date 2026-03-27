import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The single place where an endpoint turns into a request, so every call carries
/// the same headers and nothing drifts between them.
struct RequestBuilder {

    let configuration: LingvanexConfiguration

    func makeRequest<Response>(for endpoint: Endpoint<Response>) throws -> URLRequest {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw LingvanexError.notConfigured
        }

        let target = configuration.baseURL.appendingPathComponent(endpoint.path)
        guard var components = URLComponents(url: target, resolvingAgainstBaseURL: false) else {
            throw LingvanexError.invalidURL
        }
        components.queryItems = endpoint.query.isEmpty ? nil : endpoint.query

        guard let url = components.url else {
            throw LingvanexError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = configuration.timeout
        request.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")

        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }
}
