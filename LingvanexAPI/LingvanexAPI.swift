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
    
    
    public struct LanguagesResult: Decodable {
        let err: String?
        let result: [Languages]
    }
    
    public struct Languages: Decodable {
        /// the language code in the format “language code_code of the country”
        public let fullCode: String
        /// the language code in the “language code” format
        public let name: String?
        /// English name of the language
        public let englishName: String
        /// the language name translated using the language specified by the query parameter “code”
        public let codeName: String
        /// the relative address of which is the image of the country flag. Example static/flags/afrikaans. The full address for downloading the flag will be https://backenster.com/v2/static/flags/afrikaans.png. In order to download flags in increased resolutions, you should add to this parameter: @2x or @3x (example https://backenster.com/v2/static/flags/afrikaans@2x.png or https://backenster.com/v2/static/flags/afrikaans@3x.png)
        public let flagPath: String
        /// a word for testing a speech synthesizer
        public let testWordForSyntezis: String
        /// an array of objects, each of which is a description of the function that is supported in the given language
        public let modes: [Mode]
        
        enum CodingKeys: String, CodingKey {
            case name, englishName, codeName, flagPath, testWordForSyntezis, modes
            case fullCode = "full_code"
        }
    }
    
    public struct Mode: Decodable {
        /// name of the function. Currently, only 4 functions are widely supported: “Speech synthesis“, “Image recognition“, “Translation“, “Speech recognition“
        public let name: String
        /// logical value true or false, which shows the status of the function: on or off
        public let value: Bool
        /// logical value true or false, which shows the ability to synthesize speech for both sexes. Displayed only for function “Speech synthesis“
        public let genders: Bool?
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
        guard let url = URLComponents(string: API.translate.url)?.url else {
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
    
    
    /**
    Getting the list of languages

    - Parameters:
        - platform: api
        - code: the language code in the format “language code_code of the country”, which is used to display the names of the languages. The language code is represented only in lowercase letters, the country code only in uppercase letters (example en_GB, es_ES, ru_RU etc). If this option is not present, then English is used by default
    */
    
    @available(iOS 10.0, *)
    public func getLanguages(_ code: String?, _ platform: String = "api", _ completion: @escaping ((_ translate: [Languages]?, _ error: Error?) -> Void)) {
        guard var urlComponents = URLComponents(string: API.getLanguages.url) else {
            completion(nil, nil)
            return
        }
        
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "platform", value: platform))
        if let code = code {
            queryItems.append(URLQueryItem(name: "code", value: code))
        }
        urlComponents.queryItems = queryItems
                
        guard let url = urlComponents.url else {
            completion(nil, nil)
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = API.getLanguages.method
        urlRequest.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        
        let task = session.dataTask(with: urlRequest) { (data, response, error) in
            guard let data = data,                                // is there data
                  let response = response as? HTTPURLResponse,    // is there HTTP response
                  (200 ..< 300) ~= response.statusCode,           // is statusCode 2XX
                  error == nil else {                             // was there no error, otherwise ...
                
                completion(nil, error)
                return
            }
            
            guard let loaded = try? JSONDecoder().decode(LanguagesResult.self, from: data) else {
                completion(nil, error)
                return
            }
            
            completion(loaded.result, nil)
        }
        task.resume()
    }
    
}
