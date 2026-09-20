# 0006 XcodeGen project generation and xcconfig configuration

Status: Accepted · Date: 2026-09-18

## Context

`.xcodeproj` files are hard to review and merge. Build settings scattered
across the project are hard to audit.

## Decision

- `project.yml` is the source of truth; `ReportingBuilder.xcodeproj` is
  generated with XcodeGen and committed for convenience. CI always builds
  from a freshly generated project and warns if the committed one drifted.
- All tunable settings live in `Config/*.xcconfig`: versions, deployment
  target, feature flags. They reach runtime through Info.plist substitution
  and `AppConfiguration`.

## Consequences

- Reviewers can read the whole build configuration in two short text files.
- Changing a feature flag per configuration is a one-line change with no
  code edits.
- Contributors who change targets need `brew install xcodegen`.
