import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Performs one HTTP exchange. Async so that cancelling the calling task cancels the
/// request itself, and so decorators can be written as plain sequential code.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {

    private let session: URLSession

    public init(configuration: URLSessionConfiguration = .default) {
        session = URLSession(configuration: configuration)
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LingvanexError.emptyResponse
            }
            return (data, http)
        } catch let error as LingvanexError {
            throw error
        } catch is CancellationError {
            throw LingvanexError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw LingvanexError.cancelled
        } catch let error as URLError {
            throw LingvanexError.transport(underlying: error)
        } catch {
            throw LingvanexError.transport(underlying: TransportFailure(error))
        }
    }
}
