<p align="center">
    <img width="522" alt="LingvanexAPI" src="https://github.com/artdima/LingvanexAPI/blob/main/logo.png?raw=true">
</p>

<p align="center">
    <a href="https://github.com/artdima/LingvanexAPI/actions/workflows/ci.yml"><img src="https://github.com/artdima/LingvanexAPI/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
    <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0-orange.svg" alt="Swift 6.0"></a>
    <img src="https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS%20%7C%20Linux-lightgrey.svg" alt="Platforms">
    <a href="https://cocoapods.org/pods/LingvanexAPI"><img src="https://img.shields.io/cocoapods/v/LingvanexAPI.svg" alt="CocoaPods"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT"></a>
</p>

# LingvanexAPI

A Swift client for the [Lingvanex Translation API](https://lingvanex.com/documentation-api/):
text translation and the list of supported languages.

- `async`/`await`, with cancellation reaching the request
- typed errors that say what went wrong and what to do about it
- batch translation in a single request
- language codes as a type, so the source and target cannot be swapped
- retries with backoff for the failures that time can fix
- no dependencies; the whole networking stack is replaceable for tests

## Installation

**Swift Package Manager**

```swift
dependencies: [
    .package(url: "https://github.com/artdima/LingvanexAPI.git", from: "2.0.0")
]
```

**CocoaPods**

```ruby
pod 'LingvanexAPI', '~> 2.0'
```

## Getting started

Create an [account](https://lingvanex.com/account) and generate an API key at the bottom
of the page. Keep it out of your source: read it from a configuration file, a keychain,
or your server.

```swift
import LingvanexAPI

let client = LingvanexClient(apiKey: key)

let translation = try await client.translate("Hello", to: .ruRU)
print(translation.text ?? "")            // Привет
```

The key is part of construction, so a client that is not configured cannot exist, and
several clients can coexist with different keys, environments or timeouts.

### Detecting the source language

Omit `from` and the service detects it, reporting what it found:

```swift
let translation = try await client.translate("Bonjour", to: .enGB)
print(translation.detectedSourceLanguage ?? "unknown")   // fr_FR
```

### Translating a list

One request instead of N, which matters when you are paying per call:

```swift
let translation = try await client.translate(.batch(["Hello", "Goodbye"]), to: .ruRU)
print(translation.output.values)          // ["Привет", "Пока"]
```

### HTML and transliteration

```swift
let options = TranslationOptions(mode: .html, includeTransliteration: true)
let translation = try await client.translate(markup, to: .ruRU, options: options)

print(translation.transliteration?.target ?? "")
```

`mode: .html` keeps markup intact instead of translating the tags along with the text.
Transliteration is absent from the response unless you ask for it.

### Listing languages

```swift
let languages = try await client.languages(displayLanguage: .ruRU)

for language in languages where language.features.contains(where: { $0.name == "Translation" }) {
    print(language.fullCode, language.localizedName ?? language.englishName)
}
```

## Handling failures

Every failure is a `LingvanexError`, and each case says something different about what to do:

```swift
do {
    let translation = try await client.translate(text, to: target)
    show(translation.text)
} catch let error as LingvanexError {
    switch error {
    case .unauthorized:
        askForANewKey()
    case let .rateLimited(retryAfter, _):
        scheduleRetry(after: retryAfter ?? 60)
    case .cancelled:
        break
    case let .decoding(failure, _):
        report("Lingvanex changed \(failure.field ?? "a field"): \(failure.reason)")
    default:
        show(error.localizedDescription)
    }
}
```

`LingvanexError` conforms to `LocalizedError`, so `errorDescription`, `failureReason` and
`recoverySuggestion` are fit to put in front of a user.

## Cancellation

Cancelling the task cancels the request. In SwiftUI, `.task(id:)` does it for you when the
input changes or the view goes away — which is what makes a translate-as-you-type field
cost one request instead of one per keystroke:

```swift
.task(id: text) {
    guard !text.isEmpty else { return }
    try? await Task.sleep(for: .milliseconds(300))     // debounce
    translation = try? await client.translate(text, to: target)
}
```

## Configuration

```swift
var configuration = LingvanexConfiguration(apiKey: key)
configuration.timeout = 10
configuration.retryPolicy = RetryPolicy(maximumAttempts: 5, baseDelay: 0.5)
configuration.logger = { print($0) }         // the Authorization header is redacted
configuration.baseURL = onPremiseURL         // for a self-hosted Lingvanex install

let client = LingvanexClient(configuration: configuration)
```

Retries apply to `429`, `5xx` and network timeouts, with exponential backoff, jitter and
`Retry-After` honoured. A rejected key or a malformed request is never retried — it would
be refused just as firmly on the second attempt.

## Testing against it

The networking stack is a protocol, so your tests never need a network or a key:

```swift
struct StubTransport: HTTPTransport {
    let body: Data

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

var configuration = LingvanexConfiguration(apiKey: "test")
configuration.transport = StubTransport(body: fixture)
let client = LingvanexClient(configuration: configuration)
```

## Requirements

| | |
| --- | --- |
| Swift | 6.0 |
| iOS | 15.0 |
| macOS | 12.0 |
| tvOS | 15.0 |
| watchOS | 8.0 |
| visionOS | 1.0 |
| Linux | Swift 6.0 toolchain |

## Upgrading from 0.x

Existing code keeps compiling: the old `LingvanexAPI` singleton and its completion
handlers forward to the new client and are deprecated with their replacements named.
They are removed in 3.0. See [MIGRATION.md](MIGRATION.md) for the mapping, and
[CHANGELOG.md](CHANGELOG.md) for what changed and why.

Two behaviours could not be preserved, and both are bug fixes: a failure now arrives as a
`LingvanexError` instead of `(nil, nil)`, and an unconfigured client reports
`.notConfigured` instead of crashing.

## License

MIT. See [LICENSE](LICENSE).
