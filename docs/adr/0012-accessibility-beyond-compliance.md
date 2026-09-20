# 0012 Accessibility beyond compliance

Status: Accepted · Date: 2026-09-20

## Context

Passing a checklist is the floor. The people who write status reports mostly
do not use a screen reader, so they cannot tell what their report is like for a
colleague who does. The goal of this round was to let an author experience
their card the way others will, and to use the platform's accessibility
features rather than merely not breaking them.

## Decision

For the author, in the Accessibility tab of the inspector:

- **Hear This Card** (⌥⌘L). `SpokenRenderer` (core, pure, tested) turns the card
  into the phrases a screen reader announces: headings as headings, list
  lengths, metric changes in words, image descriptions, and "Image. No
  description." where one is missing. The app speaks it with
  `AVSpeechSynthesizer` and highlights the block being read; a transcript shows
  the same text for people who cannot hear it.
- **Colour Vision**: the canvas can show the card as seen with protanopia,
  deuteranopia, tritanopia or no colour. Implemented as a Core Image colour
  matrix over the rendered card, so editing pauses while it is on. The matrices
  are the common linear approximations: a sanity check, not a clinical tool.
- **Five more checks** (fourteen in all), each a warning with a WCAG reference:
  text that points at something by colour ("the red items"), long runs of
  capitals, images that are mostly text (on-device OCR counts the words when an
  image is added), sections without headings, very long sentences.

For the reader:

- **Large print**: the card has a text size (Standard, Large, Extra Large) that
  every renderer honours, including HTML, rich text, PNG and PDF.
- **Tagged PDF**: a vector PDF with real text, document metadata and a structure
  tree: headings, paragraphs, lists, and figures carrying their description as
  alternative text.

For VoiceOver and keyboard users of the app itself:

- **Audio Graph**: a metric's trend is exposed through `AXChartDescriptor`, so
  it can be played as pitch and stepped through, like charts in Stocks and Health.
- **Custom actions** on each block (Move Up, Move Down, Format, Delete) and a
  **Blocks rotor** to jump between blocks.
- **System settings are honoured**: Differentiate Without Colour (status shapes
  in the list), Increase Contrast (stronger edges and selection, an offer to
  switch to the High Contrast theme), Reduce Transparency (solid notices),
  Reduce Motion (already).
- **Undo and Redo** for structural edits and for card deletion, with named steps.

## Consequences

- `SpokenRenderer` mirrors the semantics of the HTML output, not VoiceOver's
  exact wording, which depends on the host app and the user's verbosity settings.
- Speech, the Audio Graph, the rotor and custom actions need a person with
  VoiceOver to verify; unit tests cover their data, not the experience.
- The tagged PDF is verified for real text, metadata and the presence of a
  structure tree. It has not been run through a PDF/UA validator.
