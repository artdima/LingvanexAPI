import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol HTTPTransport {
    func send(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void)
}

final class URLSessionTransport: HTTPTransport {

    private let session: URLSession

    init(configuration: URLSessionConfiguration = .default) {
        session = URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        session.dataTask(with: request, completionHandler: completion).resume()
    }
}
