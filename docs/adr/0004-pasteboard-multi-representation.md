# 0004 Write several pasteboard representations at once

Status: Accepted · Date: 2026-09-18

## Context

Each destination reads a different clipboard flavour: Mail and Notes prefer
RTFD, Slack and browsers read HTML, Messages reads plain text, and image
fields want PNG.

## Decision

"Copy for Email" writes one `NSPasteboardItem` carrying RTFD, RTF, HTML and
plain text. The receiving app picks the richest type it understands. Separate
"Copy as Image", "Copy as Markdown", "Copy for Slack", "Copy as Plain Text"
and "Copy HTML Source" variants exist for cases where the user wants to force
a specific flavour.

## Rationale

- One shortcut (⇧⌘C) does the right thing in most apps.
- HTML uses inline styles and table layout because mail clients strip
  stylesheets.
- Rich text always uses the light palette: it is pasted onto the
  destination's background, which is white in nearly every mail client.

## Consequences

- The image is not included in the default copy, because apps that see an
  image on the pasteboard (Slack, Messages) attach it instead of the text.
- The matrix of tested destinations lives in `docs/EXPORT_COMPATIBILITY.md`
  and must be re-verified when renderers change.
