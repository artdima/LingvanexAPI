import Foundation
import Testing
@testable import LingvanexAPI

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A value behind a lock. The test doubles below are handed to a `Sendable` transport
/// and read back from the test, so their state genuinely crosses isolation; this is
/// where `@unchecked Sendable` is earned rather than asserted.
final class Locked<Value>: @unchecked Sendable {

    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    var current: Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    @discardableResult
    func mutate<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

final class StubTransport: HTTPTransport, @unchecked Sendable {

    struct Stub: Sendable {
        var data: Data?
        var statusCode: Int = 200
        var headers: [String: String] = [:]
        var error: (any Error & Sendable)?
    }

    private struct State {
        var index = 0
        var requests: [URLRequest] = []
    }

    private let stubs: [Stub]
    private let state = Locked(State())

    var requests: [URLRequest] { state.current.requests }
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

    convenience init(failure: any Error & Sendable) {
        self.init(Stub(data: nil, statusCode: 0, error: failure))
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let stub = state.mutate { state -> Stub in
            state.requests.append(request)
            let stub = stubs[min(state.index, stubs.count - 1)]
            state.index += 1
            return stub
        }

        if let error = stub.error {
            throw error as? LingvanexError ?? LingvanexError.transport(underlying: error)
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
final class RecordingSleeper: RetrySleeper, @unchecked Sendable {

    private let recorded = Locked<[TimeInterval]>([])

    var delays: [TimeInterval] { recorded.current }

    func sleep(for duration: TimeInterval) async throws {
        recorded.mutate { $0.append(duration) }
    }
}

final class LogRecorder: @unchecked Sendable {

    private let recorded = Locked<[String]>([])

    var lines: [String] { recorded.current }

    func append(_ line: String) {
        recorded.mutate { $0.append(line) }
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
        _ transport: any HTTPTransport,
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
