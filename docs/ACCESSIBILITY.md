# Accessibility

Two things must be accessible: the app, and the cards people share.

## The cards

### Linter rules

`AccessibilityLinter` evaluates every card on each change. The shield in the
toolbar turns red and shows a count when there are errors. The Accessibility
tab of the Format inspector (⇧⌘K) lists the issues; selecting one selects the
block at fault and scrolls to it. An image without a description also carries
an "Add Description" button on the canvas, under the picture rather than on it,
so it never hides part of a chart. The fourteen rules and their WCAG 2.1
success criteria:

| Rule | Severity | Criterion |
|---|---|---|
| Card has a title | error | 2.4.6 Headings and Labels |
| Images have text alternatives (or are marked decorative) | error | 1.1.1 Non-text Content |
| Alt text is descriptive (not a file name, not just "screenshot", under 200 chars) | warning | 1.1.1 |
| Body text contrast ≥ 4.5:1 on background and tiles. Change indicators (▲ ▼ and their numbers) on tiles are checked under this rule, as a warning | error | 1.4.3 Contrast (Minimum) |
| Secondary text contrast ≥ 4.5:1 | warning | 1.4.3 |
| Accent contrast ≥ 3:1 | warning | 1.4.11 Non-text Contrast |
| Status indicator contrast ≥ 3:1 for all five statuses (the label itself is body text) | warning | 1.4.11 Non-text Contrast |
| Every metric has a label | error | 1.3.1 Info and Relationships |
| No empty blocks | warning | best practice |
| Sections have headings (three or more sections) | warning | 2.4.10 Section Headings |
| Text does not point at things by colour alone ("the red items") | warning | 1.4.1 Use of Color |
| Images are not used in place of text (on-device OCR counts the words) | warning | 1.4.5 Images of Text |
| No long runs of capital letters | warning | best practice |
| Sentences are a readable length | warning | 3.1.5 Reading Level |

Contrast uses the WCAG relative-luminance formula implemented in `HexColor`
and verified against published values (`#777777` on white = 4.48:1). Unit
tests assert that all four built-in themes and all six templates pass.

### Exported artifacts

- **HTML**: `lang` attribute, `<h1>`/`<h2>` hierarchy (shiftable with `baseHeadingLevel`), `<section aria-labelledby>`,
  `<ul>` for bullets, `<table>` with `scope="col"`/`scope="row"` for the
  table layout, `<figure>`/`<figcaption>` with `alt` (empty plus
  `role="presentation"` for decorative images), explicit `width`/`height` to
  avoid layout shift. Change glyphs are `aria-hidden` and paired with
  visually hidden words ("up 5%, positive"). Status is always words
  ("On Track", announced as "Status: On Track") beside a shape that differs
  per status, never colour alone. Indicator colours are Apple's
  increased-contrast system palette.
- **Markdown / plain text**: alt text appears as `![alt](file)` or
  `[Image: alt]`; changes are spelled out.
- **PNG**: an image has no semantics. The app never offers PNG as the only
  path; "Copy for Email" carries text, and the share sheet includes HTML and
  plain text representations alongside the image.
- **RTF/RTFD**: has no alt attribute. Captions are included; this is a known
  limitation documented in the README.

### For the reader

- **Large print.** A card has a text size (Standard, Large, Extra Large). HTML,
  rich text, PNG and PDF all scale their type; padding and layout stay put.
- **Tagged PDF.** Export ▸ PDF Document writes a vector PDF with selectable text,
  document title/author, and a structure tree: H1 for the title, H2 for section
  headings, paragraphs, lists, and figures whose description is the image's alt
  text. Decorative images stay outside the tree, so they are skipped.

### For the author: experience it, do not just pass it

- **Hear This Card** (Accessibility tab, ⌥⌘L) speaks the card in the order and
  words a screen reader presents it, highlighting each block as it goes. Remove
  an image description and you hear "Image. No description." Pressing play opens
  the transcript, which shows the same text. The line being spoken carries a speaker
  glyph as well as the accent colour, and the gap is in red and in words.
- **Colour Vision** shows the card as seen with protanopia, deuteranopia,
  tritanopia or no colour at all. It is an approximation, meant to catch a card
  that only works if you can tell red from green.

## The app

- Every action is reachable from the menu bar with a keyboard shortcut
  (⌘N, ⌘D, ⇧⌘C, ⌥⌘C, ⇧⌘V, ⌥⌘T / ⌥⌘M / ⌥⌘G to insert, ⌥⌘I for the inspector,
  ⇧⌘K for the accessibility check, ⌘⌫, and ⌥⌘↑ / ⌥⌘↓ / ⌥⌘⌫ for the selected
  block). Tab moves through every field on the card in reading order.
- The canvas shows no per-block chrome, but never at the cost of access:
  arrange and delete are in the Format inspector, the context menu and the Card
  menu. Drag and drop is an addition, never the only way.
- Fields on the card are labelled for VoiceOver ("Title", "Value of Velocity",
  "Change of Open bugs"); a block announces its kind and whether it is selected.
- Icon-only buttons carry `accessibilityLabel`s; groups use
  `accessibilityElement(children: .combine/.contain)` so VoiceOver reads a
  metric tile as one sentence ("Velocity: 42, up 5%, positive, trend over 5
  points from 36 to 42").
- Metric trends are **Audio Graphs** (`AXChartDescriptor`): VoiceOver can play the
  line as pitch and step through its points, as in Stocks and Health.
- Each block offers **custom actions** in VoiceOver's Actions rotor (Move Up, Move
  Down, Format, Delete), and a **Blocks rotor** jumps from block to block.
- **System settings are honoured.** Differentiate Without Colour turns the list's
  status dots into shapes; Increase Contrast strengthens the card's edge and the
  selection outline and offers the High Contrast theme; Reduce Transparency makes
  notices solid; Reduce Motion removes the banner slide and scroll animation.
- **Undo and Redo** (⌘Z, ⇧⌘Z) cover adding, moving, deleting and restyling blocks,
  assistant rewrites, and deleting a card, each with a named menu item.
- Confirmations ("Copied. Paste into Mail…") are posted as VoiceOver
  announcements as well as shown visually.
- Reduce Motion disables the banner slide and scroll animation.
- The editor uses semantic fonts and follows the system text size. The card
  preview uses fixed sizes because it is an artifact with a known width; a
  high-contrast theme is provided for the card itself.
- The toolbar verdict changes its glyph (a tick in a shield, or an exclamation
  mark in a filled red shield) and its label, so it is never colour alone.
- `Tests/AppUITests` runs XCTest's `performAccessibilityAudit()` on the main
  window, which checks contrast, missing labels, hit-region size, dynamic
  type clipping and more. UI tests run from Xcode (⌘U); macOS asks the person
  at the keyboard to allow UI automation, so they are not part of `make test`.

## Manual verification script (for the demo)

1. System Settings → Accessibility → VoiceOver on (⌘F5).
2. VO-right-arrow through the sidebar: hear "Weekly status, On track".
3. Tab into the editor; hear "Card title, Weekly status".
4. Navigate to a metrics tile in the preview; hear the full sentence.
5. Select the image, clear its description in the inspector; the toolbar shield
   reads "1 accessibility error"; press ⇧⌘K; activate the issue; the image is
   selected and the Block tab opens on its description.
6. Press ⇧⌘C; hear "Copied. Paste into Mail, Notes or Slack."
7. Press ⌥⌘L: the Mac reads the card and the canvas follows along. With the image
   description cleared it says "Image. No description."
8. With VoiceOver on a metric tile, open the rotor and choose Audio Graph; play it.
   Use the Blocks rotor to jump between blocks, and the Actions rotor to move one.
9. Accessibility tab ▸ Colour Vision ▸ Deuteranopia: nothing on the card depends on
   telling the change colours apart, because each has an arrow and words.
10. Turn on Increase Contrast, Differentiate Without Colour and Reduce Motion;
    edges strengthen, list dots become shapes, the banner appears without motion.
