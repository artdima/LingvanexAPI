//
//  LingvanexAPI.swift
//  LingvanexAPI
//
//  Created by Medyannik Dmitri on 07.02.2021.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A helper class for using Lingvanex API
public class LingvanexAPI {

    /// Shared instance.
    public static let shared = LingvanexAPI()

    private var configuration: LingvanexConfiguration
    private let transport: HTTPTransport

    init(configuration: LingvanexConfiguration = LingvanexConfiguration(), transport: HTTPTransport? = nil) {
        self.configuration = configuration
        self.transport = transport ?? Self.makeTransport(for: configuration)
    }

    /**
    Initialization.

    - Parameters:
        - apiKey: A valid API key to handle requests for this API. Authentication of requests is done by adding the “Authorization” header with the following data format: Bearer The key can be created on the user control panel page https://lingvanex.com/account.
    */
    public func start(with apiKey: String) {
        configuration.apiKey = apiKey
    }

    /**
    Translates input text, returning translated text.

    - Parameters:
        - from: The language code in the format “language code_code of the country” from which the text is translated. The language code is represented only in lowercase letters, the country code only in uppercase letters (example en_GB, es_ES, ru_RU and etc.). If this parameter is not present, the auto-detect language mode is enabled
        - to:  Language code in the format “language code_code of the country” to which the text is translated (required)
        - data: Data for translation (required). Two types of data are supported: a string and an array of strings
        - platform: api
    */
    public func translate(
        _ from: String,
        _ to: String,
        _ data: String,
        _ platform: String = "api",
        _ completion: @escaping ((_ translate: Translation?, _ error: Error?) -> Void)
    ) {
        let request = TranslateRequest(from: from, to: to, data: data, platform: platform)

        let endpoint: Endpoint<Translation>
        do {
            endpoint = try .translate(request)
        } catch {
            completion(nil, error)
            return
        }

        perform(endpoint, completion: completion)
    }

    /**
    Getting the list of languages

    - Parameters:
        - platform: api
        - code: the language code in the format “language code_code of the country”, which is used to display the names of the languages. The language code is represented only in lowercase letters, the country code only in uppercase letters (example en_GB, es_ES, ru_RU etc). If this option is not present, then English is used by default
    */
    public func getLanguages(
        _ code: String?,
        _ platform: String = "api",
        _ completion: @escaping ((_ languages: [Language]?, _ error: Error?) -> Void)
    ) {
        let endpoint = Endpoint<LanguageListResponse>.languages(displayLanguage: code, platform: platform)

        perform(endpoint) { payload, error in
            completion(payload?.result, error)
        }
    }

    /// Every call goes through here: one place for building the request, validating the
    /// answer, decoding it and turning any failure into a LingvanexError.
    private func perform<Response: Decodable>(
        _ endpoint: Endpoint<Response>,
        completion: @escaping (Response?, Error?) -> Void
    ) {
        let request: URLRequest
        do {
            request = try RequestBuilder(configuration: configuration).makeRequest(for: endpoint)
        } catch {
            completion(nil, error)
            return
        }

        transport.send(request) { data, response, error in
            do {
                let body = try ResponseValidator.validate(data: data, response: response, error: error)
                let decoded = try ResponseValidator.decode(Response.self, from: body)
                completion(decoded, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    private static func makeTransport(for configuration: LingvanexConfiguration) -> HTTPTransport {
        let session = URLSessionTransport(configuration: configuration.sessionConfiguration)
        let retrying = RetryingTransport(wrapping: session, policy: configuration.retryPolicy)

        guard let logger = configuration.logger else {
            return retrying
        }
        return LoggingTransport(wrapping: retrying, sink: logger)
    }
}
