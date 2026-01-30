import Foundation
@testable import LingvanexAPI

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class StubTransport: HTTPTransport {

    struct Stub {
        var data: Data?
        var statusCode: Int = 200
        var headers: [String: String] = [:]
        var error: Error?
    }

    private let stub: Stub
    private(set) var requests: [URLRequest] = []

    var lastRequest: URLRequest? { requests.last }

    init(_ stub: Stub) {
        self.stub = stub
    }

    convenience init(data: Data?, statusCode: Int = 200, headers: [String: String] = [:]) {
        self.init(Stub(data: data, statusCode: statusCode, headers: headers))
    }

    convenience init(failure: Error) {
        self.init(Stub(data: nil, statusCode: 0, error: failure))
    }

    func send(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        requests.append(request)

        if let error = stub.error {
            completion(nil, nil, error)
            return
        }

        guard let url = request.url else {
            completion(nil, nil, URLError(.badURL))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )
        completion(stub.data, response, nil)
    }
}
