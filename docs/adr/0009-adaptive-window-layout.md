# 0009 Adaptive window layout

Status: Accepted · Date: 2026-09-20

## Context

The brief says "responsive". The first build had a 980-point minimum window
width and clipped the preview when columns were narrow.

## Decision

The main window reflows at two breakpoints (`WindowLayout`):

| Width | Layout |
|---|---|
| ≥ 1100 | sidebar · editor · preview |
| 760–1099 | editor · preview, sidebar collapsed (toolbar button restores it) |
| < 760 (minimum 560) | one pane, with an Edit / Preview switch in the toolbar |

The preview always scales the card to the column instead of clipping it, and
states the scale ("64%"). Layout changes happen only when a breakpoint is
crossed, so a sidebar reopened by hand is respected while resizing.

## Consequences

- Breakpoints sit above the sum of the minimum column widths of the wider
  layout, otherwise the window could never shrink far enough to trigger them.
- In the compact layout the detail column hosts either pane; the hidden
  content column still exists, which keeps a single `NavigationSplitView` and
  avoids rebuilding state when crossing breakpoints.
- `-windowSize WxH -uiTesting` lets UI tests and screenshots pin each layout.
