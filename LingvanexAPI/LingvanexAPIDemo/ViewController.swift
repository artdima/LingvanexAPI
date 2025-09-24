//
//  ViewController.swift
//  LingvanexAPIDemo
//
//  Created by Dmitry Medyannik on 08.02.2021.
//

import UIKit

final class ViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard let apiKey = Secrets.apiKey else {
            print("API key is not configured. Copy Secrets.example.xcconfig to Secrets.xcconfig and set LINGVANEX_API_KEY.")
            return
        }

        LingvanexAPI.shared.start(with: apiKey)

        LingvanexAPI.shared.translate("en_GB", "ru_RU", "Hello") { translate, error in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            if let result = translate?.result {
                print(result)
            }
        }

        LingvanexAPI.shared.getLanguages(nil) { languages, error in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            languages?.forEach { print($0.englishName) }
        }
    }
}
