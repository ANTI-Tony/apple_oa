# 0005 Accessibility linter as a product feature

Status: Accepted · Date: 2026-09-18

## Context

"Accessibility-compliant" cards depend on content decisions the author makes
(alt text, meaningful labels, colour choices), not only on the app's own UI.

## Decision

`ReportCore` ships an `AccessibilityLinter` with rules mapped to WCAG 2.1
success criteria. The app shows the verdict live as a badge above the
preview; the badge opens a report that lets the user jump to the offending
block. (An earlier iteration used a permanent inspector column; it was
replaced by the popover to keep the window to three calm columns.)
Built-in themes and templates are unit-tested against the linter so the
defaults are always clean.

## Rationale

- Enforcing at authoring time is cheaper than auditing after sharing.
- Making the rules visible teaches users what "accessible" means.
- Rules are pure functions over the model, so they are trivially testable.

## Consequences

- Errors (missing alt text, low contrast, missing labels) do not block
  copying; the badge makes the state obvious instead. A stricter mode could
  gate export behind a clean report.
- Rules are heuristics. They catch the common failures, not every one.
