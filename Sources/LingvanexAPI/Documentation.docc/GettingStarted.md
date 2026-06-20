# Getting started

From an API key to a translated string.

## Get a key

Create an account at [lingvanex.com/account](https://lingvanex.com/account) and generate
an API key at the bottom of the page.

Keep it out of your source. On Apple platforms, read it from a build configuration file
that is not in version control, or from the keychain; better still, keep it on a server
and let the app talk to that. A key committed to a repository has to be treated as
compromised the moment it is pushed.

## Make a client

```swift
import LingvanexAPI

let client = LingvanexClient(apiKey: key)
```

``LingvanexClient`` is a value type and carries no shared state, so you can hold one per
screen, per feature, or one for the whole app — whichever suits the code.

## Translate

```swift
let translation = try await client.translate("Hello", to: .ruRU)
print(translation.text ?? "")
```

Omit the source language and the service detects it:

```swift
let translation = try await client.translate("Bonjour", to: .enGB)
print(translation.detectedSourceLanguage ?? "unknown")
```

Send a list to translate it in one request:

```swift
let translation = try await client.translate(.batch(["Hello", "Goodbye"]), to: .ruRU)
print(translation.output.values)
```

## Ask for more

``TranslationOptions`` covers the two switches the service offers. Transliteration is
absent from the response unless you ask for it, and HTML mode keeps markup intact
instead of translating the tags:

```swift
let options = TranslationOptions(mode: .html, includeTransliteration: true)
let translation = try await client.translate(markup, to: .ruRU, options: options)
```

## List the languages

```swift
let languages = try await client.languages(displayLanguage: .ruRU)
```

Each ``Language`` reports what the service can do for it in ``Language/features``:
translation, speech synthesis, speech recognition, image recognition.

## Tune the client

``LingvanexConfiguration`` holds the base address, timeouts, the retry policy, an optional
log sink and a replaceable transport:

```swift
var configuration = LingvanexConfiguration(apiKey: key)
configuration.timeout = 10
configuration.logger = { print($0) }
let client = LingvanexClient(configuration: configuration)
```

The log sink never sees the key: the `Authorization` header is redacted before the line
is written.
