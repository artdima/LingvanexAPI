## What this changes

<!-- One or two sentences. What does a user of the library see differently? -->

## Why

<!-- The problem, not the patch. Link the issue if there is one. -->

## Checklist

- [ ] `swift build -Xswiftc -warnings-as-errors` is clean
- [ ] `swift test` passes
- [ ] `swiftlint lint --strict` passes
- [ ] Every new code path that can fail has a test
- [ ] No test touches the network or waits on real time
- [ ] Public API changes are in `CHANGELOG.md` under Unreleased
- [ ] A rename keeps the old name as `@available(*, deprecated, renamed:)`
