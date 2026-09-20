# 0001 Native macOS app in Swift instead of a web app

Status: Accepted · Date: 2026-09-18

## Context

The brief allows a web or macOS proof of concept. The target users are
enterprise staff assembling status updates for email and messaging tools.
Reviewers work on Macs and have Xcode.

## Decision

Build a native macOS app in Swift and SwiftUI, with the domain logic in a
platform-neutral Swift package.

## Rationale

- Copy and share are the product. AppKit's pasteboard can carry rich text
  with embedded images, HTML and plain text in one write, and the system
  share sheet reaches Mail, Messages, AirDrop and Notes with no integration
  work. Browsers cannot write RTFD.
- Accessibility is a first-class platform feature: VoiceOver, Full Keyboard
  Access, Increase Contrast and Reduce Motion are honoured by SwiftUI controls,
  and XCTest can audit the running app.
- "Responsive" maps to adaptive layout: the three-column window collapses as
  it narrows, and the core package already compiles for iOS/iPadOS.
- The engineering toolchain (SwiftPM, Swift Testing, XCUITest, xcconfig,
  SwiftLint) is standard and familiar to the reviewers.

## Consequences

- Cloud deployment applies to distribution (notarisation, Apple Business
  Manager/MDM), not hosting. See `docs/DEPLOYMENT.md`.
- Reviewers build from source; the app is ad-hoc signed by default.
- A web version would reuse `ReportCore`'s HTML renderer but needs a
  separate UI. Out of scope for the POC.
