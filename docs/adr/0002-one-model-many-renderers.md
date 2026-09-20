# 0002 One card model, many renderers

Status: Accepted · Date: 2026-09-18

## Context

A card must look the same in the live preview, in a PNG, in an email and in
a chat message, and each destination accepts a different format.

## Decision

`SnippetCard` is a plain `Codable`, `Sendable` value type. Every output is a
pure function of it:

| Renderer | Output | Used for |
|----------|--------|----------|
| `CardView` (SwiftUI) | pixels | preview, PNG via `ImageRenderer`, drag preview |
| `HTMLRenderer` | inline-styled `<article>` or standalone page | email paste, HTML export, share |
| `AttributedCardRenderer` | `NSAttributedString` (RTF/RTFD) | Mail, Notes, TextEdit paste |
| `MarkdownRenderer` | CommonMark or Slack mrkdwn | chat and wiki tools |
| `PlainTextRenderer` | text | Messages, fallback |

Renderers never mutate the model and hold no state beyond options.

## Consequences

- Adding a destination means adding a renderer and its tests, nothing else.
- Templates, persistence, import/export and the accessibility linter all
  operate on the same type, so they compose for free.
- The model deliberately supports a tiny text markup (bullets and
  paragraphs) rather than full Markdown, so every renderer can agree on it.
