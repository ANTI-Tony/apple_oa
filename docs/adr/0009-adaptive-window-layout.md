# 0009 Adaptive window layout

Status: Accepted · Date: 2026-09-20

## Context

The brief says "responsive". The first build had a 980-point minimum window
width and clipped the preview when columns were narrow.

## Decision

The main window reflows at two breakpoints (`WindowLayout`):

| Width | Layout |
|---|---|
| ≥ 1080 | card list · canvas · Format inspector |
| 780–1079 | canvas · inspector, list collapsed (toolbar button restores it) |
| < 780 (minimum 480) | canvas only; the inspector is one toolbar click away |

The card on the canvas is fluid, so it reflows to the space it has instead of
being clipped. Layout changes happen only when a breakpoint is crossed, so a
list or inspector reopened by hand is respected while resizing. (The first
version of this ADR described an editor/preview pair with an Edit/Preview
switch; ADR 0010 replaced that pair with a single canvas.)

## Consequences

- Breakpoints sit above the sum of the minimum column widths of the wider
  layout, otherwise the window could never shrink far enough to trigger them.
- The window width is read from a `GeometryReader` around the split view. The
  split view's own width is useless for this: it never reports less than the
  minimum of its visible columns, which hides exactly the case to react to.
- `-windowSize WxH -uiTesting` lets UI tests and screenshots pin each layout.
