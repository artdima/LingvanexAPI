# Handling failures

What can go wrong, and what each failure asks you to do.

## Overview

Every call throws ``LingvanexError``. The cases are separated by what a caller would
reasonably do about them, not by where in the stack they arose.

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
    default:
        show(error.localizedDescription)
    }
}
```

## Showing a failure to a user

``LingvanexError`` conforms to `LocalizedError`. `errorDescription` prefers the message the
service sent over a generic one, `failureReason` explains the category, and
`recoverySuggestion` says what to try next.

## Diagnosing a changed contract

``LingvanexError/decoding(_:rawBody:)`` carries a ``DecodingFailure`` naming the field, the
kind of mismatch and where in the response it happened, plus a truncated copy of the body:

```swift
case let .decoding(failure, rawBody):
    logger.error("Lingvanex response changed: \(failure.reason)")
    logger.debug("body: \(rawBody ?? "")")
```

This is the failure to watch in production. The service is not yours, and a field that
stops arriving shows up here rather than as a silent wrong answer.

## What retries already handle

``RetryingTransport`` is in the default stack, so `429`, `5xx` and network timeouts have
already been retried with backoff before an error reaches you. A ``LingvanexError`` that
you catch is one that survived the policy — retrying it yourself is unlikely to help,
except for ``LingvanexError/rateLimited(retryAfter:message:)`` after the stated delay.

A rejected key, a malformed request and a cancelled call are never retried.

## Cancellation

``LingvanexError/cancelled`` means the caller cancelled the task, not that anything went
wrong. It is usually the one case to swallow rather than show.
