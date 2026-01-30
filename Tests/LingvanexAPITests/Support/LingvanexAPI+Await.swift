import Foundation
@testable import LingvanexAPI

extension LingvanexAPI {

    func translated(
        from: String = "en_GB",
        to: String = "ru_RU",
        text: String = "Hello"
    ) async -> (value: Translate?, error: Error?) {
        await withCheckedContinuation { continuation in
            translate(from, to, text) { translation, error in
                continuation.resume(returning: (value: translation, error: error))
            }
        }
    }

    func languageList(displayLanguage: String? = nil) async -> (value: [Languages]?, error: Error?) {
        await withCheckedContinuation { continuation in
            getLanguages(displayLanguage) { languages, error in
                continuation.resume(returning: (value: languages, error: error))
            }
        }
    }

    static func stubbed(_ transport: StubTransport, key: String = "test-key") -> LingvanexAPI {
        let api = LingvanexAPI(transport: transport)
        api.start(with: key)
        return api
    }
}
