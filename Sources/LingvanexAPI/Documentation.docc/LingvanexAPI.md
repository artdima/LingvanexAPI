# ``LingvanexAPI``

A Swift client for the Lingvanex Translation API.

## Overview

``LingvanexClient`` takes its key at construction, so a client that is not configured
cannot exist. Its methods are `async` and throwing: cancelling the calling task cancels
the request, and every failure arrives as a ``LingvanexError`` that says what went wrong.

```swift
let client = LingvanexClient(apiKey: key)
let translation = try await client.translate("Hello", to: .ruRU)
print(translation.text ?? "")
```

## Topics

### Getting started

- <doc:GettingStarted>
- ``LingvanexClient``
- ``LingvanexConfiguration``
- ``APIKey``

### Translating

- ``TranslationInput``
- ``TranslationOptions``
- ``Translation``
- ``TranslationOutput``
- ``Transliteration``

### Languages

- ``LanguageCode``
- ``Language``
- ``LanguageFeature``

### Failures

- <doc:ErrorHandling>
- ``LingvanexError``
- ``DecodingFailure``
- ``TransportFailure``

### Networking

- ``HTTPTransport``
- ``URLSessionTransport``
- ``RetryingTransport``
- ``LoggingTransport``
- ``RetryPolicy``
- ``RetrySleeper``

### Upgrading

- <doc:Migration>
