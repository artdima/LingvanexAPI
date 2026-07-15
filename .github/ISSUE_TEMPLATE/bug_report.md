---
name: Bug report
about: Something the library does that it should not
labels: bug
---

## What happened

<!-- Include the LingvanexError you got, if any: its case and its localizedDescription. -->

## What you expected

## How to reproduce

```swift
// The smallest snippet that shows it.
```

## If it is a decoding failure

`LingvanexError.decoding` carries a `DecodingFailure` and a truncated body. Both are worth
pasting — they name the field that changed:

```
failure.reason:
rawBody:
```

## Environment

| | |
| --- | --- |
| LingvanexAPI | |
| Installed via | SwiftPM / CocoaPods |
| Swift | |
| Platform and version | |
