# Contributing

## Setup

```sh
brew install xcodegen swiftlint swiftformat   # xcodegen only if you change project.yml
make generate                                  # regenerates ReportingBuilder.xcodeproj
make open
```

Requirements: macOS 14 or later, Xcode 16 or later (developed and tested on Xcode 26.3, Swift 6.2).

## Workflow

1. Branch from `main`: `feat/<topic>`, `fix/<topic>`, `docs/<topic>`.
2. Keep the core package free of UI frameworks. Anything that imports AppKit or SwiftUI belongs in `App/`.
3. Add or update tests with every change. Core logic gets a Swift Testing case in `Packages/ReportCore/Tests`; app behaviour gets a case in `Tests/AppTests`; user-visible flows get a UI test.
4. Run the checks before pushing:

   ```sh
   make test          # core + app unit tests
   make lint          # SwiftLint, strict
   make format-check  # SwiftFormat, no changes expected
   ```

5. UI tests (`make test-ui`) drive the real app, so macOS must allow
   automation for whatever launches them. Running them from Xcode (select the
   `ReportingBuilderUITests` target, ⌘U) handles the permission prompt; from a
   plain terminal you may see "Timed out while enabling automation mode" until
   the terminal app is granted Accessibility access in System Settings →
   Privacy & Security.
6. Record any decision that a future reader might question as an ADR in `docs/adr/`.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/):

```
feat(export): add Slack-flavoured Markdown
fix(parser): treat percent columns as points, not percent-of-percent
docs(adr): record pasteboard representation strategy
test(store): cover import of duplicate identifiers
chore(ci): cache SwiftPM build
```

Subject in the imperative, 72 characters or fewer. The body explains *why*.

## Pull request checklist

- [ ] Tests added or updated, `make test` green
- [ ] `make lint` and `make format-check` clean
- [ ] `project.yml` changed? Then `make generate` was run and the project committed
- [ ] User-facing strings added? Then `Localizable.xcstrings` updated
- [ ] Accessibility: new controls have labels; new colours pass the linter tests
- [ ] Docs updated (README, ADR, CHANGELOG)

## Code style

- Swift 6 language mode with strict concurrency. UI-facing types are `@MainActor`; core types are value types and `Sendable`.
- Prefer small views. A view file over ~200 lines is a hint to split.
- Comment the *why*, not the *what*. Public API in `ReportCore` carries `///` docs.
- No force unwraps outside tests.
