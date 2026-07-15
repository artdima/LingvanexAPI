# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/).

## [2.0.0] - Unreleased

The first version with a stable public API. There is no 1.x: nothing was ever
released under that number, and the major was raised to 2.0 to match the scale of
the change from 0.1.0. The 0.x entry point still compiles
but is deprecated throughout and will be removed in 3.0. See [MIGRATION.md](MIGRATION.md).

### Fixed

- **Translation responses no longer fail to decode.** `sourceTransliteration` and
  `targetTransliteration` were required by the model, but the service only sends
  them when the request asks for transliteration — which the client never did.
  Every ordinary translation therefore failed to decode, and the failure was
  swallowed. They are now an optional `transliteration` block, and the request
  can ask for them.
- **Failures are reported.** Every failure used to arrive as `(nil, nil)`:
  a rejected key, an exhausted quota, a server error, a malformed body and a
  changed contract were all indistinguishable from each other and from success.
  Each is now a `LingvanexError` case.
- **The message the service sends is no longer discarded.** The response body was
  thrown away on any non-2xx status; it is now read and its `err` text reaches the
  caller.
- **An error inside a 200 response is a failure.** The `err` field was decoded and
  never checked, so a throttled or rejected call could be reported as success with
  an empty result.
- **Using the client without a key no longer crashes.** It reports `.notConfigured`.
- **One missing optional field no longer discards the whole response.** Only the
  translated text, and a language's code and English name, are required.

### Added

- `LingvanexClient`: a value type that takes its key at construction, with
  `async`/`await` methods. Cancelling the calling task cancels the request.
- `LanguageCode`: a validated `language_COUNTRY` type, so the source and target
  languages can no longer be swapped by accident.
- Batch translation via `TranslationInput.batch`, which the service supported all
  along: one request instead of N.
- `TranslationOptions` for HTML mode and transliteration.
- Automatic detection of the source language by omitting it.
- Retries for transient failures: exponential backoff with jitter, capped attempts,
  and `Retry-After` honoured. A rejected key or a bad request is never retried.
- `LingvanexConfiguration`: base address, timeouts, connectivity behaviour, retry
  policy, an optional log sink and a replaceable transport.
- `APIKey`, which masks itself when printed or interpolated.
- `LocalizedError` messages, including which field of a response failed to decode.
- `Accept` and a versioned `User-Agent` on every request.
- Tests: request shape, decoding, every failure path, retry behaviour on a
  controlled clock, cancellation, and parity between the old and new API.
- DocC documentation, published from CI: getting started, error handling and the
  migration from 0.x.
- `CONTRIBUTING.md`, `SECURITY.md` and issue and pull request templates.

### Changed

- Minimum platforms are now iOS 15, macOS 12, tvOS 15 and watchOS 8, so the client
  can use the async `URLSession` API and propagate cancellation.
- `Translate` → `Translation`, `Languages` → `Language`, `Mode` → `LanguageFeature`.
  The old names remain as deprecated typealiases.
- `Translation.result` → `output`, which is a string or a list mirroring the input;
  `text` is the convenience for the single-string case.
- The vendor's `testWordForSyntezis` typo and the `full_code` snake case no longer
  appear in the public API.
- Request bodies are compact rather than pretty-printed.
- Request timeout is 20 seconds instead of the URLSession default of 60, and the
  session waits for connectivity instead of failing on a momentary drop.

### Removed

- `LanguagesResult`. It was public with internal members, so nothing could be read
  from it outside the module.

### Deprecated

- `LingvanexAPI` and its `shared`, `start(with:)`, `translate(_:_:_:_:_:)` and
  `getLanguages(_:_:_:)`. They forward to `LingvanexClient` and are removed in 3.0.

### Security

- The demo application no longer contains an API key. The key it used to carry was
  committed to the public history and must be treated as compromised.

## [0.1.0] - 2021-02-08

- Initial release: `translate` and `getLanguages` on a shared instance with
  completion handlers.
