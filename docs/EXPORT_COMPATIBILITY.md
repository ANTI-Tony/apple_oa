# Export and paste compatibility

"Copy for Email" writes one pasteboard item with four representations:

| UTI | Produced by | Who reads it |
|---|---|---|
| `public.rtfd` | `AttributedCardRenderer` | Mail, Notes, TextEdit, Pages (rich text with images) |
| `public.rtf` | same, images dropped | apps that read RTF but not RTFD |
| `public.html` | `HTMLRenderer(.email)` | Slack, Teams, browsers, Outlook web, Gmail |
| `public.utf8-plain-text` | `PlainTextRenderer` | Messages, terminals, everything else |

Other variants write a single representation so the user can force a
flavour: image (PNG + TIFF), Markdown, Slack mrkdwn, plain text, HTML source.

## Matrix

Status legend: **verified** = pasted and inspected by hand on macOS 15.6;
*expected* = based on the app's documented pasteboard behaviour, not yet
checked by hand. Re-verify after changing any renderer.

"Copy for Email" was checked by hand into Mail, Notes, Messages and Slack.
Every other cell in this table is still *expected*, including the "Copy as
Image" column for those same four apps.

| Destination | Copy for Email | Copy as Image | Copy as Markdown / Slack | Notes |
|---|---|---|---|---|
| Apple Mail (macOS) | **verified**: rich text with headings, table, inline image | *expected*: inline image | plain | Mail prefers RTFD. Table renders via `NSTextTable`. |
| Apple Notes | **verified**: rich text with image | *expected* | plain | |
| TextEdit (rich) | *expected*: rich text with image | *expected* | plain | Useful for quick inspection. |
| Messages | **verified**: plain text (Messages ignores RTF) | *expected*: image bubble | plain | Use "Copy as Image" for a visual card. |
| Slack (desktop) | **verified**: HTML converted to Slack formatting; images dropped | *expected*: attaches image | "Copy for Slack" gives exact mrkdwn | Slack reads `public.html` then `text/plain`. |
| Microsoft Teams | *expected*: HTML formatting kept | *expected* | Markdown mostly ignored; use rich | |
| Outlook (macOS) | *expected*: rich text or HTML | *expected* | plain | Outlook's Word engine ignores some CSS; layout uses tables for this reason. |
| Gmail (web) | *expected*: HTML with inline styles | *expected* | plain | Gmail strips `<style>`, keeps inline styles; data-URI images may be blocked, so use the PNG for images. |
| Confluence / Notion | Markdown export or paste | image | "Copy as Markdown" | GFM table supported. |
| Finder (drag from preview) | n/a | *expected*: `<title>.png` file | n/a | via `FileRepresentation`. |

## Known behaviours

- Apps that see an image on the pasteboard usually attach it and ignore
  text. That is why the default copy omits the image and "Copy as Image" is a
  separate action.
- Rich text uses the light palette regardless of the card theme, because
  the destination background is almost always white.
- Email HTML uses inline styles and `<table role="presentation">` for tile
  layout. This is deliberate: Outlook desktop and Gmail drop stylesheets and
  flexbox.
- HTML export as a file is a full responsive page (viewport meta, tiles
  stack under 480 px) and is what you would host.

## How to verify a destination

1. Select the "Weekly status" sample card.
2. ⇧⌘C, paste into the destination, screenshot.
3. Record the outcome in this file (change *expected* to **verified** with
   the OS/app version) and add the screenshot to `docs/assets/`.
