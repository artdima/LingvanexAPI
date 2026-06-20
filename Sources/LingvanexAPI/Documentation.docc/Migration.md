# Migrating from 0.x

Existing code keeps compiling; the compiler points at every replacement.

## Overview

The 0.x entry point — the `LingvanexAPI` singleton, `start(with:)` and the two completion
methods — still exists and forwards to ``LingvanexClient``. Everything is marked deprecated
with its replacement named, and all of it is removed in 2.0.

The full mapping of renamed types and properties is in `MIGRATION.md` at the root of the
repository.

## Two behaviours that changed

These could not be preserved by a wrapper, and both are the fixes the rewrite was for.

**A failure is reported.** In 0.x every failure arrived as `(nil, nil)`: a rejected key, an
exhausted quota, a server error and a changed response shape were indistinguishable from
each other and from an empty result. They are now ``LingvanexError`` cases.

**An unconfigured client does not crash.** Calling before `start(with:)` used to force
unwrap a `nil` key. It now reports ``LingvanexError/notConfigured``.

## The shape of the change

```swift
// 0.x
LingvanexAPI.shared.start(with: "KEY")
LingvanexAPI.shared.translate("en_GB", "ru_RU", "Hello") { translate, error in
    if let error = error { print(error.localizedDescription); return }
    print(translate?.result ?? "")
}

// 1.0
let client = LingvanexClient(apiKey: "KEY")
let translation = try await client.translate("Hello", from: .enGB, to: .ruRU)
print(translation.text ?? "")
```

Beyond the syntax, the new signature reaches things the old one could not express: omitting
`from` enables the service's language detection, ``TranslationInput/batch(_:)`` translates a
list in one request, and typed ``LanguageCode`` values make a swapped source and target a
compile error instead of a quietly wrong translation.
