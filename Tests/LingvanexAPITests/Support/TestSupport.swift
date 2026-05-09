import Foundation
import Testing
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

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)

        let stub = stubs[min(index, stubs.count - 1)]
        index += 1

        if let error = stub.error {
            throw error is LingvanexError ? error : LingvanexError.transport(underlying: error)
        }

        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: stub.statusCode,
                  httpVersion: "HTTP/1.1",
                  headerFields: stub.headers
              ) else {
            throw LingvanexError.emptyResponse
        }

        return (stub.data ?? Data(), response)
    }
}

/// Never answers until the task is cancelled.
struct HangingTransport: HTTPTransport {

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            try await Task.sleep(nanoseconds: 5_000_000_000)
        } catch {
            throw LingvanexError.cancelled
        }
        throw LingvanexError.emptyResponse
    }
}

/// Returns immediately and records what it was asked to wait for, so backoff can be
/// asserted without spending real seconds.
final class RecordingSleeper: RetrySleeper {

    private(set) var delays: [TimeInterval] = []

    func sleep(for duration: TimeInterval) async throws {
        delays.append(duration)
    }
}

final class LogRecorder {

    private(set) var lines: [String] = []

    func append(_ line: String) {
        lines.append(line)
    }
}

enum Fixture {

    enum Failure: Error, CustomStringConvertible {
        case notFound(String)

        var description: String {
            switch self {
            case let .notFound(name):
                return "Fixture \(name).json is not in the test bundle."
            }
        }
    }

    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw Failure.notFound(name)
        }
        return try Data(contentsOf: url)
    }
}

extension LingvanexError {

    /// Case name only, so a test can assert which failure happened without unwrapping payloads.
    var label: String {
        switch self {
        case .notConfigured: return "notConfigured"
        case .invalidLanguageCode: return "invalidLanguageCode"
        case .invalidURL: return "invalidURL"
        case .encoding: return "encoding"
        case .transport: return "transport"
        case .cancelled: return "cancelled"
        case .unauthorized: return "unauthorized"
        case .rateLimited: return "rateLimited"
        case .server: return "server"
        case .decoding: return "decoding"
        case .emptyResponse: return "emptyResponse"
        }
    }
}

extension LingvanexClient {

    static func stubbed(
        _ transport: HTTPTransport,
        apiKey: String = "test-key",
        configure: (inout LingvanexConfiguration) -> Void = { _ in }
    ) -> LingvanexClient {
        var configuration = LingvanexConfiguration(apiKey: APIKey(apiKey))
        configure(&configuration)
        configuration.transport = transport
        return LingvanexClient(configuration: configuration)
    }
}

/// Runs a throwing call and returns the LingvanexError it produced, recording an issue
/// if it succeeded or failed with something else.
func lingvanexFailure(_ body: () async throws -> Void) async -> LingvanexError? {
    do {
        try await body()
        Issue.record("Expected a LingvanexError, but the call succeeded")
        return nil
    } catch let error as LingvanexError {
        return error
    } catch {
        Issue.record("Expected a LingvanexError, got \(error)")
        return nil
    }
}
