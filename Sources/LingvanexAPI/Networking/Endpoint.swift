import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

/// One call the service offers. The generic parameter is what its body decodes into,
/// so the pipeline can infer the response type from the endpoint alone.
struct Endpoint<Response: Decodable>: Sendable {
    let path: String
    let method: HTTPMethod
    var query: [URLQueryItem] = []
    var body: Data?
}

extension Endpoint where Response == Translation {

    static func translate(_ request: TranslateRequest) throws -> Endpoint {
        do {
            return Endpoint(path: "translate", method: .post, body: try JSONEncoder().encode(request))
        } catch {
            throw LingvanexError.encoding(reason: error.localizedDescription)
        }
    }
}

extension Endpoint where Response == LanguageListResponse {

    static func languages(displayLanguage: LanguageCode?, platform: String) -> Endpoint {
        var query = [URLQueryItem(name: "platform", value: platform)]
        if let displayLanguage {
            query.append(URLQueryItem(name: "code", value: displayLanguage.rawValue))
        }
        return Endpoint(path: "getLanguages", method: .get, query: query)
    }
}
