# 0008 Headless CLI and static gallery as the first cloud surface

Status: Accepted · Date: 2026-09-20

## Context

The brief lists "choice of technologies to deploy on cloud" as a plus. A Mac
app is distributed rather than hosted, and ADR 0003 keeps user data local, so
there was nothing running in the cloud, only a document describing options.

## Decision

- Add `reportcard`, a dependency-free command-line tool in the `ReportCore`
  package (`ReportCLIKit` library + thin executable). It renders cards from
  templates or JSON in every text format, lints them for accessibility with
  CI-friendly exit codes, and generates a static gallery.
- Publish that gallery to GitHub Pages and the app to GitHub Releases from
  GitHub Actions.

## Rationale

- The renderers were already pure Swift over a value type, so going headless
  cost a few hundred lines and no changes to rendering code. That is the
  payoff of ADR 0002.
- The gallery proves the exported HTML is responsive and accessible in real
  browsers, which the Mac app alone cannot show.
- `reportcard lint` turns the accessibility rules into a pipeline gate, an
  enterprise use the GUI cannot serve.
- Pages, Releases and Actions need no servers, accounts or secrets.

## Consequences

- Dates in CLI output default to `en_US` so CI output is stable; `--locale`
  overrides. Templates accept an injected date and locale for the same reason.
- `HTMLRenderer` gained `baseHeadingLevel` so embedded cards do not break the
  host page's heading outline.
- PNG export stays app-only: it needs SwiftUI's `ImageRenderer`.
