## LingvanexAPI

[![Version](https://img.shields.io/cocoapods/v/LingvanexAPI.svg?style=flat)](http://cocoadocs.org/artdima/LingvanexAPI)

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
