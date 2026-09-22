# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Redesigned the app on the iWork model: the card is edited in place on a
  canvas, with a Format inspector (Card, Block, Accessibility) instead of a
  form and a preview. Restyled the card and every export typographically
  (large title, sentence-case headings, rounded numerals, one grouped metrics
  surface, status as words with an indicator) using Apple's increased-contrast
  system colours. New icon. The Ocean theme became Paper. Status labels use
  title case. A single newline is now a line break in every renderer.
- Window breakpoints are 1080 and 780 pt; minimum width 480 pt. The export
  width chosen in the inspector now applies to PNG, HTML, share and drag.
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
- Writing assistance (opt-in, provider-agnostic): New Card from Notes and Refine
  for text blocks, with Apple's on-device model or a configurable
  OpenAI-compatible endpoint, Keychain storage, per-host consent, and a defensive
  reply parser. The remote path is for demonstration only (ADR 0011).
- Accessibility beyond compliance (ADR 0012): Hear This Card with follow-along
  highlight and transcript; colour-vision simulation; five more linter rules
  (fourteen in all) including images-of-text via on-device OCR; large print across
  every export; tagged PDF export and printing; Audio Graphs for metric trends;
  VoiceOver block actions and a Blocks rotor; Differentiate Without Colour,
  Increase Contrast and Reduce Transparency honoured; Undo and Redo; Continuity
  Camera import.
- A Help menu (⌘?) opening a guide in its own window: every bound shortcut,
  grouped by menu and spelled out for VoiceOver; what each state of the toolbar
  shield means, with a button that opens the real check; where cards are stored;
  and the build's version and feature flags. Menus and guide take their key
  equivalents from one `MenuShortcut` catalogue, so the guide cannot name a
  shortcut the app does not bind (ADR 0013). The three insert tooltips now show
  their shortcuts too.
- UI tests for the undescribed-image prompt, Hear This Card (muted), Colour Vision
  and New Card from Notes with a canned model.

### Fixed
- Export moved from the Card menu to **File ▸ Export**, beside Import Cards,
  which is where macOS puts it and where people look for it. The tagged PDF
  had been shipping since the accessibility round and was effectively
  undiscoverable; the README's export list did not mention it either. A UI
  test now asserts the File menu holds Import and Export.
- The "Add Description" prompt sat on top of the image and could hide part of a
  chart, and its white-on-orange label failed contrast. It now sits under the
  image as a bordered button with a warning glyph.
- The toolbar shield did not turn red, because a toolbar draws template symbols in
  its own colour. It is now a palette symbol.
- The line being spoken in the transcript was marked by colour alone. It now has
  a speaker glyph, and pressing play opens the transcript.
- The Done button of the colour-vision banner was merged into a static text
  element and could not be reached on its own with VoiceOver.
- Every image in the deck carries a description. PptxGenJS writes the file's
  absolute path as the alternative text when none is given, so the slides both
  leaked a local path and would have read out that path to a screen reader.
- Inspector: the accessibility verdict wrapped ragged-left in a trailing column,
  section footers did not line up with their headers, and the empty-selection
  placeholder was oversized for a narrow column.
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
