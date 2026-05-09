import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum ResponseValidator {

    private static let rawBodyPreviewLimit = 512

    /// Turns an answer into a body to decode, or throws the most specific error available.
    static func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        let message = serverMessage(in: data)

        switch response.statusCode {
        case 200 ..< 300:
            if let message {
                throw LingvanexError.server(status: response.statusCode, message: message)
            }
            guard !data.isEmpty else {
                throw LingvanexError.emptyResponse
            }
            return data

        case 401, 403:
            throw LingvanexError.unauthorized(message: message)

        case 429:
            throw LingvanexError.rateLimited(retryAfter: RetryDecision.retryAfter(for: response), message: message)

        default:
            throw LingvanexError.server(status: response.statusCode, message: message)
        }
    }

    static func decode<Payload: Decodable>(_ type: Payload.Type, from data: Data) throws -> Payload {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let decodingError as DecodingError {
            throw LingvanexError.decoding(underlying: decodingError, rawBody: preview(of: data))
        }
    }

    /// The service reports failures in the body, so it is read on every status, not only on 2xx.
    /// A body that is not JSON is a normal outcome here and carries no message.
    private static func serverMessage(in data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        do {
            let envelope = try JSONDecoder().decode(ServerEnvelope.self, from: data)
            guard let message = envelope.err, !message.isEmpty else { return nil }
            return message
        } catch {
            return nil
        }
    }

    private static func preview(of data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        let text = String(decoding: data.prefix(rawBodyPreviewLimit), as: UTF8.self)
        return data.count > rawBodyPreviewLimit ? text + "…" : text
    }
}
