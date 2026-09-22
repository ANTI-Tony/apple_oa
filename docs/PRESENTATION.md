# Presentation (15 minutes)

The deck is [deck/Reporting-Builder.pptx](../deck/Reporting-Builder.pptx): 16 slides, with
the full script in the speaker notes. It opens in Keynote or PowerPoint. The script below is
generated from the same source as those notes (`deck/notes.js`), so the two cannot drift.

## Shape of the talk

| Clock | Part | Slides |
|---|---|---|
| 0:00–1:48 | The problem, and what I built | 1–3 |
| 1:48–4:48 | **Live demo** | 4 |
| 4:48–7:06 | How it is put together: the renderers, the model, the layers | 5–7 |
| 7:06–8:36 | Accessibility, for the reader and for the author | 8–9 |
| 8:36–10:48 | The AI feature, and why its public-API path is for this exercise only | 10–11 |
| 10:48–11:48 | How it is tested | 12 |
| 11:48–13:51 | Configuration and conventions, delivery, what I would not claim yet | 13–15 |
| 13:51–14:21 | Three takeaways. The rest of the slot is slack. | 16 |

## Pacing

The script is written for about 130 words a minute, which lands at 14:21 including a
three-minute demo. Rehearse it against a clock twice, and time yourself: if your natural
pace is nearer 120 words a minute you are over the slot and need the cuts below.

- By the end of the demo the clock should read 4:48. By the end of slide 9 it should read 8:36.
- If the clock reads past 9:15 after slide 9, cut slide 13 to its first two sentences and slide 14
  to the gate and the release tag. Both slides carry their own detail on the page.
- Slides 6, 7 and 12 are the model, the layering and the testing story, which is what an
  engineering interview is actually buying. Do not cut them to save time; cut slide 13 instead.
- Never shorten slide 11. It is the one place the talk says what would not be acceptable
  in production.
- The demo is the part most likely to run long. Its six steps are on slide 4. If a paste target
  misbehaves, say so, show the matching screenshot in `docs/assets/`, and move on.

## Questions the model and architecture slides invite

**Why a separate package rather than folders in the app?** A folder is a suggestion; a package
is enforced. `ReportCore` cannot import SwiftUI even by accident, which is what keeps the
renderers pure and the tests fast. It also made the command-line tool free.

**What does Swift 6 strict concurrency actually buy here?** The card is a `Sendable` value type,
so it crosses to a background task for OCR or a network call without a lock; stores are
`@MainActor @Observable`, so the compiler rejects a stray write from a callback. The one place
it bit me was a helper on a `View` called from a test thread, fixed with `nonisolated`.

**Where would a new block kind touch?** A case on `Block`, an editable view, a static view, an
inspector section, and a branch in each renderer. The compiler's exhaustiveness checks list
every site, which is the point of the enum.

## Demo checklist

- Launch from Xcode with the arguments `-uiTesting` for the three seeded cards and in-memory storage.
  Nothing from a rehearsal is left behind.
- Sound on, and the right output device selected, for Hear This Card (⌥⌘L).
- A Numbers sheet open with a three-column table (Metric, Current, Previous), ready to copy.
- A chart screenshot on the Desktop, ready to drop.
- A Mail compose window and a Slack message to yourself open behind the app.
- Window at about 1440 × 900 so the list, the canvas and the inspector are all visible.
- **File ▸ Export** for the tagged PDF. It is on slide 3 and slide 9 and there is no toolbar route to it, so rehearse the menu path once.
- New Card from Notes is not part of the six steps. If there is time for it, either enable Writing
  Assistance in Settings beforehand with your own key, or launch with `-stubAssistant YES -uiTesting`
  to use the canned model. Say which one it is.
- VoiceOver on ⌘F5 if someone asks to hear the rotor or the Audio Graph.

## Questions to expect

**Why native and not a web app?** Copy and share are the product. The Mac pasteboard can hold rich
text with images, HTML and plain text at once, and each app takes the richest one it understands.
Accessibility, the share sheet, printing, Continuity Camera and on-device text recognition come
with the platform. ADR 0001.

**How do you know the accessibility features work?** The data is tested: the spoken segments, the
chart descriptor, the rotor entries, the lint rules, the contrast maths, the tags in the PDF. The
experience is not something a unit test can judge, and I say so. The next step would be a session
with someone who uses VoiceOver every day, and a PDF/UA validator for the PDF.

**Why a public model at all?** My Mac cannot run the on-device model, and a demo needs a model that
answers. The provider sits behind a protocol, the feature is off by default and asks for consent per
host, and one build flag removes it with the network entitlement. In production it would be the
on-device model or an approved internal gateway. ADR 0011.

**What stops the model from inventing numbers?** Nothing can, fully. The prompt forbids it, the reply
is parsed and bounded as untrusted input, nothing is saved until Create, and the sheet tells the
author to check every number. The author stays responsible for the card.

**How would this become multi-user?** The card is a Codable value with a versioned JSON form, and the
renderers are pure functions that already run headless. Share links would add a store (CloudKit, or an
internal Swift service) and leave the model and the renderers alone. ADR 0003 and ADR 0008.

**How do the tests avoid the real clipboard and network?** Unit tests write to a named scratch
pasteboard, a temporary directory and in-memory persistence, and the assistant talks to a stubbed HTTP
client. Only the UI test for Copy for Email touches the real clipboard, because that is what it tests.

**What would you do with two more weeks?** An iPad target on the same core package, share links,
localisation (the string catalog is in place), notarisation, and a usability session on the
accessibility features.

## Script

<!-- script:begin (generated by deck/presentation-md.js) -->

| Slide | Title | Starts at | Words |
|---|---|---|---|
| 1 | Reporting Builder | 0:00 | 68 |
| 2 | Every week, the same update, three times | 0:30 | 78 |
| 3 | A Mac app where the card is the document | 1:06 | 94 |
| 4 | From scattered inputs to a shared card | 1:48 | 158 |
| 5 | One model, many renderers | 4:48 | 82 |
| 6 | One value type, three kinds of block | 5:27 | 122 |
| 7 | One package below, two consumers above | 6:24 | 100 |
| 8 | Accessibility you can experience, not just pass | 7:09 | 111 |
| 9 | For those who read it, and those who write it | 8:00 | 86 |
| 10 | New Card from Notes: the brief's first sentence | 8:39 | 119 |
| 11 | For this exercise only: not how I would ship it | 9:33 | 170 |
| 12 | Fast where it is cheap, honest where it is not | 10:51 | 127 |
| 13 | Built to be read and changed | 11:51 | 79 |
| 14 | The cloud carries the software, not your data | 12:27 | 99 |
| 15 | What I would not claim yet | 13:12 | 90 |
| 16 | Three things to take away | 13:54 | 64 |

1647 words in all; the plan ends at 14:24, which leaves room inside a fifteen-minute slot.

### 1. Reporting Builder

Hello, I'm Tony. Thank you for your time. The brief asked for a tool that turns raw text, numbers and images into polished, accessible snippet cards you can share by email and chat. I built it as a native Mac app called Reporting Builder. I'll show it working first, then three design principles, how I handled accessibility and AI, the engineering, and what I would not claim yet.

### 2. Every week, the same update, three times

Think of a program manager on a Thursday afternoon. The material for the weekly update is scattered: bullet points in a notes app, numbers in a spreadsheet, a chart as a screenshot. They assemble it for email, then again for Slack, then again for the wiki. And nothing ever asks: can a colleague with a screen reader read this? Does the status still make sense without red and green? Three problems: assembling, re-formatting, and accessibility arriving too late.

### 3. A Mac app where the card is the document

This is Reporting Builder, a native Mac app in Swift and SwiftUI. On the left, your cards. In the middle, the card itself, and that is the editor: you click the title and type, as in Pages or Keynote. On the right, a Format inspector for what you cannot see on the card: theme, layout, image descriptions, and the accessibility check. Why native rather than web? Copy and share are the product, and the Mac pasteboard carries rich text, HTML and plain text at once. Accessibility is a platform feature here, not an add-on.

### 4. From scattered inputs to a shared card

Let me show you. I start a weekly status from a template and type straight onto the card. Now I copy a range from a spreadsheet and press Shift-Command-V. It recognises a table and offers metrics, with the change computed, and it knows that fewer open bugs is good news. I drop in a screenshot. The shield in the toolbar turns red, and the image asks for a description. Before I fix it, listen. [Play Hear This Card.] That's what a colleague with a screen reader gets: Image, no description. I describe it, and the check clears. Colour Vision shows the card as someone with red-green colour blindness sees it, and it still works, because every change has an arrow and words, not just colour. Finally Shift-Command-C. Paste into Mail: rich text, a real table, the image. Paste into Slack: the same copy, and Slack picks the flavour it understands. One copy, the right format in each place.

### 5. One model, many renderers

Three design principles. The first: one model, many renderers. A card is a plain value type with no UI dependencies, and every output is a pure function of it: the canvas you edit, the PNG and the PDF, inline-styled HTML for email, rich text for Mail, Markdown for Slack, plain text, even the spoken narration. That is why what you see is what you paste. It also makes a new destination cheap, and it lets the same code run without a window.

### 6. One value type, three kinds of block

And here is that model, because everything else is a function of it. A card is a struct: identity, a schema version so an older file still opens, the words you see, a status, a theme, a text size, and an ordered array of blocks. A block is an enum with exactly three cases, and that is the decision that pays for itself: every renderer in the package switches over it with no default clause, so a fourth kind of block would not compile until each of them handled it. Metrics nest one level deeper, and a change carries its direction and its sentiment as separate fields, which is how the card knows that twenty percent fewer open bugs is good news.

### 7. One package below, two consumers above

And here is how it is packaged. At the bottom one Swift package, ReportCore, importing nothing but Foundation: the model, the parsers, every renderer, the accessibility linter and the templates. Two things sit on top and neither knows the other exists: the Mac app, and a command-line tool. Dependencies point one way, and that single rule buys three things. The package's ninety tests run in under a second. The same code runs headless, which is how accessibility became a gate in the pipeline. And it already builds for iOS, so an iPad version is a target rather than a rewrite.

### 8. Accessibility you can experience, not just pass

The third principle is the one I care most about. Passing a checklist is the floor. Most people who write status reports do not use a screen reader, so they cannot tell what their report is like for someone who does. So the app lets you experience it. Hear This Card reads the card in the order and words a screen reader uses: heading level one, list of three items, velocity forty-two, up five percent, positive. If an image has no description, you hear the gap. Colour Vision shows the card under the common colour-vision deficiencies. And the linter checks fourteen rules as you type, each mapped to a WCAG criterion.

### 9. For those who read it, and those who write it

Accessibility has two audiences. For people who receive a card: large print, which every export follows, and a tagged PDF with real text, headings and figure descriptions, so a screen reader treats it as a document rather than a picture. For people who use the app with VoiceOver: a metric's trend is an Audio Graph, so you hear the line as pitch; each block has move and delete actions, and a rotor jumps between blocks. The app honours the system's contrast, colour, transparency and motion settings.

### 10. New Card from Notes: the brief's first sentence

I added one AI feature, because it answers the first sentence of the brief: quickly assemble and structure project progress. You paste rough notes, and the model returns a structured report: title, status, highlights, metrics, risks, next steps. What matters is what happens to the reply. It is treated as untrusted input: parsed defensively, every list bounded, the status mapped onto an enum, and then it goes through the same accessibility linter. The prompt forbids inventing numbers, nothing is saved until you press Create, and the sheet tells you to check every number. Refine does the same for one text block. I did not rebuild Writing Tools: with Apple Intelligence the system already provides them in every text field.

### 11. For this exercise only: not how I would ship it

Now the part I want to be very clear about. In this demo the model is a public API, DeepSeek. That is for this exercise only. I would not ship it, and I would not use it with real data. Status reports are business data. Sent to a public third-party model they leave the organisation's control: the provider's retention and training terms apply, in the provider's jurisdiction, with no data-processing agreement, no security review and no audit trail. Pasted notes can carry a prompt injection, and a model can state a wrong number confidently. So why is it here? My Mac runs macOS 15, which cannot run Apple's on-device model, and a demo needs a model that answers. But the design assumes the right answer. The provider sits behind a protocol: first Apple's Foundation Models, on device, where nothing leaves the Mac; otherwise any compatible endpoint, which in a company means an approved internal gateway with authentication, redaction and logging. It is off by default and asks consent per host.

### 12. Fast where it is cheap, honest where it is not

On testing, and the split is deliberate. Ninety tests in the package cover everything that is a pure function: parsers, renderers, contrast maths, the fourteen linter rules, and the parser that turns a model's reply into a card. They finish in under a second, so I run them constantly. Forty-seven app tests cover the store and undo, persistence, every export including the tagged PDF, and the assistant against a stubbed HTTP client. Nothing touches your clipboard, your network or your files, with one deliberate exception: the Copy for Email test uses the real pasteboard, because the pasteboard is the thing under test. And three things I do not test, and say so instead: how Mail and Slack really render a paste, the VoiceOver experience, and PDF/UA conformance.

### 13. Built to be read and changed

On the engineering around it. Configuration is not buried in the Xcode project: versions, feature flags and signing live in xcconfig files and reach the running app through one typed accessor. The project file is generated from a YAML spec, so a reviewer can read the build the way they read the code, and one flag makes writing assistance unreachable. No third-party dependencies. And twelve short decision records explain the choices someone might question, including the ones I reversed.

### 14. The cloud carries the software, not your data

The brief mentions the cloud. A Mac app is distributed rather than hosted, and user data stays local on purpose, so what ships to the cloud is the software and its output. On every push, GitHub Actions runs the tests and lint. A push to main also renders a gallery of every template, with the same HTML renderer the app uses for email, and publishes it, but only if every card passes the linter in strict mode. Accessibility becomes a pipeline gate. In an enterprise the same artifact would be notarised and distributed through Apple Business Manager or MDM.

### 15. What I would not claim yet

I want to be straightforward about what I cannot claim. The on-device model path compiles behind availability checks, but I could not run it on macOS 15. The paste matrix separates what I verified by hand from what I expect from each app's documentation. The VoiceOver features are tested for their data; the experience needs someone who uses VoiceOver every day. The tagged PDF has a structure tree, but I have not run a PDF/UA validator. Next would be an iPad target on the same core, share links, and localisation.

### 16. Three things to take away

Three things to take away. One model, many renderers: what you see is what you paste. Accessibility you can hear and see, not only pass, for the author, the reader and the VoiceOver user. And privacy as a design decision: local by default, AI opt-in, and honest about which parts are a demonstration. Thank you. I'd be glad to go deeper into any part.

<!-- script:end -->
