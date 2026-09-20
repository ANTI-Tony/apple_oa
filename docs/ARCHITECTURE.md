# Architecture

## Goals

1. **What you see is what you paste.** Every output must derive from one
   model so the preview, the PNG and the email never disagree.
2. **Accessibility is enforced at authoring time**, not audited afterwards.
3. **Lightweight.** No backend, no accounts, no third-party dependencies.
4. **Testable without a window.** Domain logic runs in `swift test` in
   under a second.

## Layers

```
App (macOS, SwiftUI + AppKit)
├── ReportingBuilderApp      scenes, environment injection, menu commands
├── Store/                   CardStore (@Observable, @MainActor), persistence, sample content
├── Workspace/               WorkspaceState (report popover, notices, copy/export), file panels,
│                            commands, focused-block key for block shortcuts
├── Views/                   MainWindow, Sidebar, Editor (block editors, import sheets),
│                            Preview (CardView, PreviewPane), Settings,
│                            Components (accessibility badge + report popover, notices)
├── Export/                  CardExporter (PNG/HTML/MD/TXT/JSON), PasteboardWriter,
│                            AttributedCardRenderer (RTF/RTFD), CardTransfer (share, drag)
├── Ingestion/               DropIngestor, PasteIngestor, ImageImport, VisionServices
├── Intents/                 CreateCardFromClipboardIntent, AppShortcutsProvider
└── Config/                  AppConfiguration (Info.plist flags), UserPreferences (UserDefaults)

ReportCLIKit + reportcard (same package, Foundation only)
└── CLI (templates, themes, render, lint, site), SiteGenerator for the Pages gallery

ReportCore (SwiftPM package, macOS 14+ / iOS 17+, Foundation only)
├── Model/                   SnippetCard, Block (text | metrics | image), CardTheme, HexColor, ReportStatus
├── Ingestion/               MetricsParser, ContentDetector, NumberParsing
├── Rendering/               HTMLRenderer, MarkdownRenderer, PlainTextRenderer, CardDateFormatting
├── Accessibility/           AccessibilityLinter (rules ↔ WCAG), contrast maths in HexColor
├── Templates/               CardTemplate (six built-ins)
└── Support/                 CardCodec (JSON), string escaping
```

Dependency direction is strictly downward. `ReportCore` imports nothing but
Foundation; it compiles for iOS as well, which keeps an iPad version a
one-target addition.

## The model

```swift
struct SnippetCard { id, schemaVersion, title, subtitle, status, blocks: [Block], theme, createdAt, updatedAt }
enum Block { case text(TextBlock), metrics(MetricsBlock), image(ImageBlock) }
struct Metric { label, value: String, change: MetricChange?, trend: [Double] }
struct MetricChange { direction: up|down|flat, sentiment: positive|negative|neutral, text }
struct ImageBlock { imageData, contentType, altText, caption, isDecorative, pixelSize, fileName }
struct CardTheme { background, surface, text, secondaryText, accent, border: HexColor, ... }
```

Design points:

- **Direction and sentiment are separate** on a change. "Open bugs ▼ 20%"
  is downward and positive. Renderers colour by sentiment and speak both.
- **Values are display strings** ("$1.2M", "81%"). Parsing to numbers happens
  at ingestion, where the source format is known, not at render time.
- **Images are bytes in the model.** A card is self-contained, so JSON export
  and the pasteboard carry everything. Large images are downscaled on import
  (`ImageImport.maxPixelWidth`).
- **Themes serialise with the card** so an export renders identically elsewhere.
- **JSON uses a `kind` discriminator** for blocks and lenient decoding with
  defaults, so older exports keep opening after fields are added. Dates are
  ISO 8601 with millisecond precision; whole-second timestamps from other
  tools decode too.

## Data flow

```
paste / drop / file ──► PasteIngestor / DropIngestor ──► ContentDetector ──► MetricsParser
                                                                │
                                                                ▼
                       CardStore.update(card) ◄──── Binding ◄── Editor views
                              │
                              ├──► FileCardPersistence (debounced 400 ms, atomic write)
                              │
                              ▼
        CardView ◄── PreviewPane        AccessibilityLinter ──► badge + report popover
           │
           ├──► ImageRenderer ──► PNG (export, Copy as Image, share, drag)
        HTMLRenderer ──► email fragment (pasteboard .html) / standalone page (export)
        AttributedCardRenderer ──► RTFD/RTF (pasteboard, images as attachments)
        MarkdownRenderer ──► CommonMark / Slack (pasteboard .string, export)
        PlainTextRenderer ──► .string fallback
```

## Concurrency model

- Swift 6 language mode, complete concurrency checking, in both targets.
- `CardStore`, `UserPreferences`, `WorkspaceState` and `ImageCache` are
  `@MainActor` `@Observable` classes. Views read them through the environment.
- `CardPersistence` is a `@MainActor` protocol; saves are debounced with a
  `Task` on the main actor and written atomically. Files are small (tens of KB
  per card with images) so this is fine for a POC; a background actor is the
  obvious next step if libraries grow.
- Vision requests run in `Task.detached` and return `Sendable` arrays.
- `NSItemProvider` callbacks are bridged with checked continuations that
  resume only with `Sendable` values.
- `CardTransfer` renders lazily on the main actor when the share sheet or a
  drop target asks for bytes.

## Configuration

| Where | What | Read by |
|---|---|---|
| `Config/Shared.xcconfig` | version, deployment target, feature flags | Info.plist via `$(VAR)` |
| `Config/Debug|Release.xcconfig` | optimisation, testability, per-flavour flag overrides | Xcode |
| `project.yml` | targets, entitlements, Info.plist keys, scheme | XcodeGen |
| `AppConfiguration` | typed access to the above at runtime | app code |
| `UserPreferences` | user choices (template, theme, PNG scale, footer) | Settings, exporters |
| Launch argument `-uiTesting` | in-memory store seeded with sample cards | `CardStore.makeDefault()` |

## Testing strategy

| Level | Tool | What | Where |
|---|---|---|---|
| Unit (core) | Swift Testing | parsers, renderers, contrast maths, linter, templates, codec | `Packages/ReportCore/Tests` |
| Unit (app) | Swift Testing | store, file persistence, export formats, pasteboard types, image normalisation, smart paste, preferences, Info.plist flags | `Tests/AppTests` |
| UI | XCUITest | launch, ⌘N/⌘D, add block, ⇧⌘C pasteboard contents, `performAccessibilityAudit()` | `Tests/AppUITests` |
| Static | SwiftLint, SwiftFormat | style and common mistakes | CI |

Tests never touch the user's real clipboard or Application Support: they use
named pasteboards, temporary directories and in-memory persistence. The one
exception is the UI test for ⇧⌘C, which exercises the real general pasteboard
by design. UI tests need macOS automation permission for the process that
launches them; run them from Xcode (⌘U) the first time.

## Adaptive layout

`WindowLayout` maps the window width to one of three arrangements: three
columns (≥ 1100 pt), editor plus preview (≥ 760 pt), or a single pane with an
Edit/Preview switch (down to 560 pt). `MainWindow` measures its width with
`onGeometryChange` and changes `NavigationSplitView` visibility only when a
breakpoint is crossed. `PreviewPane` lays the card out at its true export
width, measures it, and scales it to the column, so the preview is never
clipped and PNG export is unaffected. See ADR 0009.

## Extension points

- New block kind: add a case to `Block`, an editor view, and a branch in each
  renderer. The compiler's exhaustiveness checks list every spot.
- New destination: add a `CopyVariant` or `ExportFormat` and a renderer.
- New accessibility rule: add a case to `AccessibilityRule` and a check in
  `AccessibilityLinter`; the report and tests pick it up automatically.
- New template: add a `CardTemplate` and it appears in every menu; the
  template test verifies it is accessible out of the box.
