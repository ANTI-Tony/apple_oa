# 0007 Swift 6 language mode with strict concurrency

Status: Accepted · Date: 2026-09-18

## Context

The app mixes UI state, file I/O, pasteboard access and Vision requests.

## Decision

Both the package and the app compile in Swift 6 language mode with complete
concurrency checking. The store, preferences and workspace state are
`@MainActor` `@Observable` classes. Core types are `Sendable` value types.
Vision work runs in detached tasks and returns `Sendable` results.

## Consequences

- Data races are compile errors rather than intermittent bugs.
- Some AppKit bridging needs explicit continuations (see `DropIngestor`).
- `VNRecognizeTextRequest` is used instead of the newer Swift-only Vision
  API to keep the macOS 14 deployment target.
