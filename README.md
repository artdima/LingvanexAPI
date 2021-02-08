## LingvanexAPI

[![Version](https://img.shields.io/cocoapods/v/LingvanexAPI.svg?style=flat)](http://cocoadocs.org/artdima/LingvanexAPI)
[![License](https://img.shields.io/cocoapods/l/LingvanexAPI..svg?style=flat)](http://cocoadocs.org/artdima/LingvanexAPI)
[![Platform](https://img.shields.io/cocoapods/p/LingvanexAPI..svg?style=flat)](http://cocoadocs.org/artdima/LingvanexAPI)

A framework to use <a href="https://lingvanex.com/documentation-api/">LingvaNex Translation API</a> in Swift.


## Installation
<b>CocoaPods:</b>
<pre>
pod 'LingvanexAPI'
</pre>
<b>Carthage:</b>
<pre>
github "artdima/LingvanexAPI"
</pre>
<b>Manual:</b>
<pre>
Copy <i>LingvanexAPI.swift</i> to your project.
</pre>

## Initialization
Before using the API you need to create the <a href="https://lingvanex.com/account">account</a> and then generate the API key at the bottom of the page.
And then use the following code:
```swift
LingvanexAPI.shared.start(with: "API_KEY_HERE")
```

## Using

The framework supports 2 endpoinds: <i>translate</i> and <i>languages</i>. You can find more information in the official source. How to use from the framework.

Translation:
```swift
LingvanexAPI.shared.translate("en_GB", "ru_RU", "Hello") { (translate, error) in
    if let error = error {
        print(error.localizedDescription)
        return
    }
    
    if let t = translate?.result {
        print(t)
    }
}
```

Languages:
```swift
LingvanexAPI.shared.getLanguages(nil) { (results, error) in
    if let error = error {
        print(error.localizedDescription)
        return
    }
    
    results.map{
        print($0.description)
    }
}
```

## License

<i>LingvanexAPI</i> is available under the MIT license. See the LICENSE file for more info.
