import Foundation

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
