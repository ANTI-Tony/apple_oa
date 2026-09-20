# Accessibility

Two things must be accessible: the app, and the cards people share.

## The cards

### Linter rules

`AccessibilityLinter` evaluates every card on each change. The shield in the
toolbar turns red and shows a count when there are errors. The Accessibility
tab of the Format inspector (⇧⌘K) lists the issues; selecting one selects the
block at fault and scrolls to it. An image without a description also carries
an "Add Description" button on the canvas. Rules and their WCAG 2.1
success criteria:

| Rule | Severity | Criterion |
|---|---|---|
| Card has a title | error | 2.4.6 Headings and Labels |
| Images have text alternatives (or are marked decorative) | error | 1.1.1 Non-text Content |
| Alt text is descriptive (not a file name, not just "screenshot", under 200 chars) | warning | 1.1.1 |
| Body text contrast ≥ 4.5:1 on background and tiles | error | 1.4.3 Contrast (Minimum) |
| Secondary text contrast ≥ 4.5:1 | warning | 1.4.3 |
| Accent contrast ≥ 3:1 | warning | 1.4.11 Non-text Contrast |
| Status indicator contrast ≥ 3:1 for all five statuses (the label itself is body text) | warning | 1.4.11 Non-text Contrast |
| Change indicator contrast ≥ 4.5:1 on tiles | warning | 1.4.3 |
| Every metric has a label | error | 1.3.1 Info and Relationships |
| No empty blocks | warning | best practice |

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
- Confirmations ("Copied. Paste into Mail…") are posted as VoiceOver
  announcements as well as shown visually.
- Reduce Motion disables the banner slide and scroll animation.
- The editor uses semantic fonts and follows the system text size. The card
  preview uses fixed sizes because it is an artifact with a known width; a
  high-contrast theme is provided for the card itself.
- `Tests/AppUITests` runs XCTest's `performAccessibilityAudit()` on the main
  window, which checks contrast, missing labels, hit-region size, dynamic
  type clipping and more.

## Manual verification script (for the demo)

1. System Settings → Accessibility → VoiceOver on (⌘F5).
2. VO-right-arrow through the sidebar: hear "Weekly status, On track".
3. Tab into the editor; hear "Card title, Weekly status".
4. Navigate to a metrics tile in the preview; hear the full sentence.
5. Select the image, clear its description in the inspector; the toolbar shield
   reads "1 accessibility error"; press ⇧⌘K; activate the issue; the image is
   selected and the Block tab opens on its description.
6. Press ⇧⌘C; hear "Copied. Paste into Mail, Notes or Slack."
7. Turn on Increase Contrast and Reduce Motion; controls stay legible and the
   banner appears without motion.
