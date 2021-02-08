//
//  ViewController.swift
//  LingvanexAPIDemo
//
//  Created by Dmitry Medyannik on 08.02.2021.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        LingvanexAPI.shared.start(with: "a_W9cN8eb6C6EPY00UtltX3SaMoRchGD3LElrIxHqjC1sDdTtshh55yNykyt8a3Tl6LMftwmsEpujTpjoC")
        
        LingvanexAPI.shared.translate("en_GB", "ru_RU", "Hello") { (translate, error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            print(translate?.result)
        }
        
        LingvanexAPI.shared.getLanguages(nil) { (result, error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            result.map{
                print($0.description)
            }
        }
    }
}

