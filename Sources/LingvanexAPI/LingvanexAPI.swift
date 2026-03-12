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

    /// API structure.
    private enum API {
        /// Base Lingvanex API url.
        static let base = "https://api-b2b.backenster.com/b1/api/v3"

        static let getLanguages = base + "/getLanguages"
        static let translate = base + "/translate"
    }

    /// API key.
    private var apiKey: String?
    /// Performs the HTTP calls. Injectable so the client can be exercised without a network.
    private let transport: HTTPTransport

    init(transport: HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    /**
    Initialization.

    - Parameters:
        - apiKey: A valid API key to handle requests for this API. Authentication of requests is done by adding the “Authorization” header with the following data format: Bearer The key can be created on the user control panel page https://lingvanex.com/account.
    */
    public func start(with apiKey: String) {
        self.apiKey = apiKey
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
        let parameters: [String: Any] = [
            "from": from,
            "to": to,
            "data": data,
            "platform": platform
        ]

        let urlRequest: URLRequest
        do {
            urlRequest = try makeRequest(url: API.translate, method: "POST", body: parameters)
        } catch {
            completion(nil, error)
            return
        }

        transport.send(urlRequest) { data, response, error in
            do {
                let body = try ResponseValidator.validate(data: data, response: response, error: error)
                let translation = try ResponseValidator.decode(Translation.self, from: body)
                completion(translation, nil)
            } catch {
                completion(nil, error)
            }
        }
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
        var queryItems = [URLQueryItem(name: "platform", value: platform)]
        if let code {
            queryItems.append(URLQueryItem(name: "code", value: code))
        }

        let urlRequest: URLRequest
        do {
            urlRequest = try makeRequest(url: API.getLanguages, method: "GET", query: queryItems)
        } catch {
            completion(nil, error)
            return
        }

        transport.send(urlRequest) { data, response, error in
            do {
                let body = try ResponseValidator.validate(data: data, response: response, error: error)
                let payload = try ResponseValidator.decode(LanguageListResponse.self, from: body)
                completion(payload.result, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    private func makeRequest(
        url: String,
        method: String,
        query: [URLQueryItem] = [],
        body: [String: Any]? = nil
    ) throws -> URLRequest {
        guard let apiKey else {
            throw LingvanexError.notConfigured
        }

        guard var components = URLComponents(string: url) else {
            throw LingvanexError.invalidURL
        }
        components.queryItems = query.isEmpty ? nil : query

        guard let resolved = components.url else {
            throw LingvanexError.invalidURL
        }

        var request = URLRequest(url: resolved)
        request.httpMethod = method
        request.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
        }

        return request
    }
}
