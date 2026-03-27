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

    private let stubs: [Stub]
    private var index = 0

    private(set) var requests: [URLRequest] = []

    var lastRequest: URLRequest? { requests.last }

    /// The last stub repeats once the sequence runs out, so a retry test only has to
    /// describe the answers that differ.
    init(sequence: [Stub]) {
        stubs = sequence.isEmpty ? [Stub(data: nil)] : sequence
    }

    convenience init(_ stub: Stub) {
        self.init(sequence: [stub])
    }

    convenience init(data: Data?, statusCode: Int = 200, headers: [String: String] = [:]) {
        self.init(Stub(data: data, statusCode: statusCode, headers: headers))
    }

    convenience init(failure: Error) {
        self.init(Stub(data: nil, statusCode: 0, error: failure))
    }

    func send(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        requests.append(request)

        let stub = stubs[min(index, stubs.count - 1)]
        index += 1

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

/// Runs the retry wait immediately and records what it was asked to wait for,
/// so backoff can be asserted without spending real seconds.
final class ImmediateScheduler: RetryScheduler {

    private(set) var delays: [TimeInterval] = []

    func schedule(after delay: TimeInterval, work: @escaping () -> Void) {
        delays.append(delay)
        work()
    }
}

final class LogRecorder {

    private(set) var lines: [String] = []

    func append(_ line: String) {
        lines.append(line)
    }
}
