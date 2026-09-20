# 0011 Opt-in writing assistance, and why the remote provider is for demonstration only

Status: Accepted · Date: 2026-09-20 · Amends 0003

## Context

The brief's first sentence is "quickly assemble and structure project
progress". A language model is good at exactly that: turning rough meeting
notes into a title, a status, highlights, metrics, risks and next steps.

But status reports are business data. ADR 0003 made "nothing leaves the Mac"
a property of the app, and the app did not even request a network entitlement.
Adding a model must not quietly undo that.

## Decision

Two features, both opt-in:

- **New Card from Notes** (⇧⌘N): notes in, a structured card out.
- **Refine** a text block: Make Concise, More Formal, Fix Grammar.

Behind a provider-agnostic protocol (`TextAssistant`) with two implementations:

1. **On this Mac**: Apple's Foundation Models (macOS 26 or later with Apple
   Intelligence). Nothing leaves the device. This is the default where available.
2. **Custom endpoint**: any OpenAI-compatible HTTPS endpoint. In an enterprise
   this is the organisation's approved gateway. For this proof of concept it
   defaults to DeepSeek's public API, because the development Mac runs macOS 15
   and a demonstration needs a model that answers.

Guard rails:

- Off by default; a build flag (`FEATURE_WRITING_ASSISTANCE`) can remove it entirely.
- Text is sent only when the user presses Generate or a Refine button, and only
  the text they gave it. Images and other cards are never sent.
- First use of a remote host asks for consent naming that host; changing the
  host asks again. Settings and both features state where text is processed.
- The API key is stored in the Keychain, sent in a header, never logged.
  The session is ephemeral: no cookies, no cache.
- HTTPS is required (plain HTTP only for `localhost`, for a local model server).
- The reply is untrusted input. `CardDraftParser` extracts JSON, bounds every
  string and list, maps the status onto the enum, and the result is run through
  the accessibility linter before the user sees it. Nothing is saved until the
  user presses Create. The prompt forbids inventing numbers, and the sheet tells
  the user to check them.
- A rewrite is one named Undo step.
- Image descriptions stay with on-device Vision. The system's own Writing Tools
  already work in every text field on the card, so they are not rebuilt.

## What this is not

**Sending real project data to a public third-party model is not acceptable in
a real business setting, and this project does not claim otherwise.** The remote
path exists so the feature can be demonstrated on a Mac without Apple
Intelligence. The risks are concrete:

- **Confidentiality**: notes can contain unreleased plans, names, financials,
  incident details. Once sent, they are governed by the provider's retention and
  training terms and by the law of the provider's jurisdiction, not by the
  organisation's.
- **No contractual basis**: no data-processing agreement, no vendor security
  review, no audit trail, no data-residency guarantee.
- **Leakage through the model's behaviour**: prompt injection in pasted notes
  could steer output; a model can also state wrong numbers with confidence.
- **Key handling**: a personal API key on a laptop is not an enterprise credential.

In production the endpoint would be one of: the on-device model; a model hosted
inside the organisation's boundary; or an approved gateway that adds
authentication, redaction/DLP, logging and rate limits. The app's design already
assumes that: the endpoint and model are configuration, not code.

## Consequences

- The sandbox gains `com.apple.security.network.client`. Documentation that said
  the app makes no network calls now says it makes none unless writing
  assistance is enabled and used.
- The on-device path compiles against the macOS 26 SDK and is covered by
  availability checks, but could not be run on the development Mac (macOS 15).
  It is marked as not verified on hardware.
- The remote path is tested with a stubbed HTTP client (request shape, errors,
  parsing); a live call needs the user's own key.
