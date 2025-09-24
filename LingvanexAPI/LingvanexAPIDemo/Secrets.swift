//
//  Secrets.swift
//  LingvanexAPIDemo
//

import Foundation

enum Secrets {

    static var apiKey: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "LingvanexAPIKey") as? String,
              !value.isEmpty,
              value != "PUT_YOUR_KEY_HERE" else {
            return nil
        }
        return value
    }
}
