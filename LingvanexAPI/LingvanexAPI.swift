//
//  LingvanexAPI.swift
//  LingvanexAPI
//
//  Created by Medyannik Dmitri on 07.02.2021.
//

import Foundation
import UIKit

/// A helper class for using Lingvanex API
public class LingvanexAPI {
    
    public struct Translate: Decodable {
        /// the text of the error. It is null if the response status is 200. Otherwise, it contains a string
        public let err: String?
        /// result of translation. In the event that a line was sent to the translation, the result is also a string; if an array of strings, then we also get an array of strings
        public let result: String
        /// the number of letters translated using the Lingvanex service cache
        public let cacheUse: Int
        /// source data for translation
        public let source: String
        /// code of the source language in the format “language code”. In the case of sending a translation of an array of strings with different language content, only the language of the first element of the array is returned
        public let from: String
        /// transliteration of source data. In the event that a line was sent to the translation, the result is also a string; if an array of strings, then we also get an array of strings
        public let sourceTransliteration: String
        /// transliteration results. In the event that a line was sent to the translation, the result is also a string; if an array of strings, then we also get an array of strings
        public let targetTransliteration: String
    }
    
    /// Shared instance.
    public static let shared = LingvanexAPI()
    
    /// API structure.
    private struct API {
        /// Base Lingvanex API url.
        static let base = "https://api-b2b.backenster.com/b1/api/v3"
        
        /// Getting the list of languages
        struct getLanguages {
            static let method = "GET"
            static let url = API.base + "/getLanguages"
        }
        
        /// Text translation
        struct translate {
            static let method = "POST"
            static let url = API.base + "/translate"
        }
    }
    
    /// API key.
    private var apiKey: String!
    /// Default URL session.
    private let session = URLSession(configuration: .default)
    
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
    
    @available(iOS 10.0, *)
    public func translate(_ from: String, _ to: String, _ data: String, _ platform: String = "api", _ completion: @escaping ((_ translate: Translate?, _ error: Error?) -> Void)) {
        guard var urlComponents = URLComponents(string: API.translate.url) else {
            completion(nil, nil)
            return
        }
                
        guard let url = urlComponents.url else {
            completion(nil, nil)
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = API.translate.method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        
        let parameters: [String: Any] = [
            "from": from,
            "to": to,
            "data": data,
            "platform": platform
        ]
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
        } catch let error {
            completion(nil, error)
            return
        }
        
        let task = session.dataTask(with: urlRequest) { (data, response, error) in
            guard let data = data,                                // is there data
                  let response = response as? HTTPURLResponse,    // is there HTTP response
                  (200 ..< 300) ~= response.statusCode,           // is statusCode 2XX
                  error == nil else {                             // was there no error, otherwise ...
                
                completion(nil, error)
                return
            }
            
            guard let loaded = try? JSONDecoder().decode(Translate.self, from: data) else {
                completion(nil, error)
                return
            }
            
            completion(loaded, nil)
        }
        task.resume()
    }
    
    
}
