# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Removed the partial Simplified Chinese translation; the UI is consistently
  English and dates follow the app language.
- Templates take an injected date and locale; JSON dates keep milliseconds.
- Simplified the interface: the accessibility inspector column became a report
  popover behind the badge; blocks lost their boxes and show move/delete
  controls only on hover or keyboard focus; a metric is now a single row with
  a free-form change field (`+5%`, `-3`) and automatic good/bad inference;
  theme and preview width moved into an Appearance menu; export moved into the
  Copy menu.

### Added
- `reportcard` command-line tool (`ReportCLIKit`): render templates or JSON cards
  in every text format, `lint` with CI exit codes, `site` to build a static gallery.
- GitHub Actions: `release.yml` publishes the zipped app with a checksum to
  GitHub Releases; `pages.yml` publishes the card gallery to GitHub Pages behind
  an accessibility gate.
- Adaptive window layout: three columns, two columns, or a single pane with an
  Edit/Preview switch; minimum width down from 980 to 560 pt.
- Card `author`, shown in the footer of every export; set from Settings.
- `HTMLRenderer.Options.baseHeadingLevel` for embedding cards in other pages.
- Block shortcuts in the Card menu: Move Block Up (⌥⌘↑), Move Block Down
  (⌥⌘↓), Delete Block (⌥⌘⌫), acting on the block that has keyboard focus.

## [0.1.0] - 2026-09-18

### Added
- `ReportCore` package: `SnippetCard` model with text, metrics and image blocks; four accessible themes.
- Ingestion: CSV/TSV/JSON/“Label: value” metrics parser with automatic change and sentiment; content detector for Smart Paste; drag and drop of files, images and text.
- Rendering: HTML (email-safe inline styles and standalone page), Markdown (CommonMark and Slack), plain text, rich text (RTF/RTFD) and SwiftUI preview from one model.
- Accessibility linter with nine WCAG-mapped rules, shown live in an inspector and as a badge on the preview.
- Copy variants for Email, image, Markdown, Slack, plain text and HTML source; export to PNG, HTML, Markdown, plain text and JSON; system share sheet; drag the card out as an image.
- Six templates, live preview at three widths, sidebar search, duplicate/delete, JSON import.
- Vision assist: on-device alt-text suggestion and metric extraction from screenshots (feature flag).
- Shortcuts action “Create Card from Clipboard” (feature flag).
- Settings: default template and theme, PNG scale, footer toggle.
- Engineering: XcodeGen project, xcconfig-driven configuration and feature flags, SwiftLint/SwiftFormat, GitHub Actions CI, Swift Testing suites for core and app, XCUITest with accessibility audit, ADRs.
