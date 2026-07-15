# Migrating from 0.x to 2.0

Existing code keeps compiling. Every 0.x entry point is still there, forwards to
the new client, and is marked deprecated so the compiler points at the replacement.
They are removed in 3.0.

Two behaviours changed in ways no wrapper can hide, and both are bug fixes:

- A failure now arrives as a `LingvanexError`. In 0.x it arrived as `(nil, nil)`,
  so code that only checked `error` treated every failure as an empty result.
- An unconfigured client returns `.notConfigured` instead of crashing.

## Creating the client

```swift
// 0.x — two steps, and a crash if you got the order wrong
LingvanexAPI.shared.start(with: "KEY")

// 1.0 — the key is part of construction, so an unconfigured client cannot exist
let client = LingvanexClient(apiKey: "KEY")
```

Several clients can now coexist: different keys, different environments, different
timeouts. Configure the rest through `LingvanexConfiguration`:

```swift
var configuration = LingvanexConfiguration(apiKey: "KEY")
configuration.timeout = 10
configuration.retryPolicy = RetryPolicy(maximumAttempts: 5)
configuration.logger = { print($0) }          // the key is redacted for you
let client = LingvanexClient(configuration: configuration)
```

## Translating

```swift
// 0.x — three unlabelled strings; swapping the first two compiled fine
LingvanexAPI.shared.translate("en_GB", "ru_RU", "Hello") { translate, error in
    if let error = error { print(error.localizedDescription); return }
    print(translate?.result ?? "")
}

// 1.0 — labelled arguments and typed language codes; the swap is now a compile error
let translation = try await client.translate("Hello", from: .enGB, to: .ruRU)
print(translation.text ?? "")
```

Omit `from` to let the service detect the language:

```swift
let translation = try await client.translate("Hello", to: .ruRU)
print(translation.detectedSourceLanguage ?? "unknown")
```

Translate a list in one request instead of N:

```swift
let translation = try await client.translate(.batch(["Hello", "Goodbye"]), to: .ruRU)
print(translation.output.values)
```

Ask for HTML mode or transliteration:

```swift
let options = TranslationOptions(mode: .html, includeTransliteration: true)
let translation = try await client.translate(markup, to: .ruRU, options: options)
print(translation.transliteration?.target ?? "")
```

## Listing languages

```swift
// 0.x
LingvanexAPI.shared.getLanguages(nil) { languages, error in … }

// 1.0
let languages = try await client.languages(displayLanguage: .ruRU)
```

## Handling failures

```swift
do {
    let translation = try await client.translate("Hello", to: .ruRU)
    show(translation.text)
} catch let error as LingvanexError {
    switch error {
    case .unauthorized:
        askForANewKey()
    case let .rateLimited(retryAfter, _):
        scheduleRetry(after: retryAfter ?? 60)
    case .cancelled:
        break
    default:
        show(error.localizedDescription)
    }
}
```

`LingvanexError` conforms to `LocalizedError`, so `errorDescription`,
`failureReason` and `recoverySuggestion` are fit to show a user.

## Cancellation

Cancelling the task cancels the request. In SwiftUI, `.task(id:)` does it for you
when the input changes or the view disappears:

```swift
.task(id: text) {
    guard !text.isEmpty else { return }
    try? await Task.sleep(for: .milliseconds(300))   // debounce
    translation = try? await client.translate(text, to: target)
}
```

## Renamed types and properties

| 0.x | 2.0 |
| --- | --- |
| `LingvanexAPI.Translate` | `Translation` |
| `LingvanexAPI.Languages` | `Language` |
| `LingvanexAPI.Mode` | `LanguageFeature` |
| `Translation.result` | `Translation.text`, or `output` for a batch |
| `Translation.from` | `Translation.detectedSourceLanguage` |
| `Translation.cacheUse` | `Translation.charactersFromCache` |
| `Translation.sourceTransliteration` | `Translation.transliteration?.source` |
| `Translation.targetTransliteration` | `Translation.transliteration?.target` |
| `Language.name` | `Language.code` |
| `Language.codeName` | `Language.localizedName` |
| `Language.testWordForSyntezis` | `Language.testWordForSynthesis` |
| `Language.modes` | `Language.features` |
| `LanguageFeature.value` | `LanguageFeature.isEnabled` |
| `LanguageFeature.genders` | `LanguageFeature.supportsBothGenders` |
| `LanguagesResult` | removed — it exposed nothing outside the module |
| `Translation.err` | thrown as a `LingvanexError` |

## Minimum platforms

iOS 15, macOS 12, tvOS 15, watchOS 8. This is what the async `URLSession` API needs,
and it is what makes cancellation reach the request rather than stopping at the
client.
