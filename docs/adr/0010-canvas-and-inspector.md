# 0010 Canvas and inspector instead of form and preview

Status: Accepted · Date: 2026-09-20 · Supersedes the editor layout described in 0005 and 0009

## Context

The first interface was a form on the left and a live preview on the right.
It worked, but it is the shape of a web utility, not of a Mac document app:
you described the card in one place and looked at it in another, every block
carried its own labelled boxes, and the card itself borrowed the visual
language of a web dashboard (capitalised section labels, tinted pills,
bordered tiles, a gradient icon).

## Decision

Follow the iWork model.

- **The card is the editor.** It sits on a desk like a page in Pages. You click
  the title and type; metrics are edited on the tile; "- " becomes a bullet as
  in Notes. There is no separate preview because nothing is being previewed.
- **A Format inspector** on the right, toggled from the toolbar with the
  paintbrush, with three tabs: Card (theme, status, author, width), Block
  (layout, per-metric sentiment, image description, arrange) and
  Accessibility (the linter's verdict, issues, and every rule). Stock grouped
  forms, segmented control, swatches. Image description lives here, which is
  where Keynote and Pages put it.
- **A typographic card.** Hierarchy from size and weight: a 28 pt title,
  sentence-case headings, SF Rounded numerals, one quiet group for metrics with
  hairline dividers, status as words beside a small indicator. Colours are
  Apple's increased-contrast system palette, so they hold 3:1 and 4.5:1.
  The HTML, rich text and PNG outputs were restyled to match.
- **A plain icon**: the card itself, in one blue, on a white plate.

## Rationale

- Direct manipulation is the platform's idiom, and it removes a whole column.
- Properties that are not visible on the card need a home; an inspector is the
  home Mac users already know.
- The static `CardView` (export) and the editable canvas are built from the
  same `CardStyle`, `CardSurface` and `MetricsGroup`, so they cannot drift.

## Consequences

- The canvas is fluid rather than scaled: text fields do not survive
  `scaleEffect` well, so a narrow window reflows the card and the export still
  renders at the chosen width.
- A single newline is now a line break in every renderer, because that is what
  typing Return on the canvas looks like.
- Block selection follows keyboard focus; arrange and delete are in the
  inspector, the context menu and the Card menu (⌥⌘↑, ⌥⌘↓, ⌥⌘⌫).
- Window breakpoints changed: the list collapses below 1080 pt and the
  inspector below 780 pt; the minimum width is 480 pt.
