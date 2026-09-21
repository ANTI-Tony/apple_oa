// The talk, slide by slide. One source for the deck's speaker notes and docs/PRESENTATION.md.
// Budget: about 1,400 spoken words plus a three-minute live demo, for a fifteen-minute slot.
module.exports = [
  {
    title: "Reporting Builder",
    minutes: 0.5,
    notes: `Hello, I'm Tony. Thank you for your time. The brief asked for a tool that turns raw text, numbers and images into polished, accessible snippet cards you can share by email and chat. I built it as a native Mac app called Reporting Builder. I'll show it working first, then three design principles, how I handled accessibility and AI, the engineering, and what I would not claim yet.`,
  },
  {
    title: "Every week, the same update, three times",
    minutes: 0.6,
    notes: `Think of a program manager on a Thursday afternoon. The material for the weekly update is scattered: bullet points in a notes app, numbers in a spreadsheet, a chart as a screenshot. They assemble it for email, then again for Slack, then again for the wiki. And nothing ever asks: can a colleague with a screen reader read this? Does the status still make sense without red and green? Three problems: assembling, re-formatting, and accessibility arriving too late.`,
  },
  {
    title: "A Mac app where the card is the document",
    minutes: 0.7,
    notes: `This is Reporting Builder, a native Mac app in Swift and SwiftUI. On the left, your cards. In the middle, the card itself, and that is the editor: you click the title and type, as in Pages or Keynote. On the right, a Format inspector for what you cannot see on the card: theme, layout, image descriptions, and the accessibility check. Why native rather than web? Copy and share are the product, and the Mac pasteboard carries rich text, HTML and plain text at once. Accessibility is a platform feature here, not an add-on.`,
  },
  {
    title: "From scattered inputs to a shared card",
    minutes: 3.0,
    notes: `Let me show you. I start a weekly status from a template and type straight onto the card. Now I copy a range from a spreadsheet and press Shift-Command-V. It recognises a table and offers metrics, with the change computed, and it knows that fewer open bugs is good news. I drop in a screenshot. The shield in the toolbar turns red, and the image asks for a description. Before I fix it, listen. [Play Hear This Card.] That's what a colleague with a screen reader gets: Image, no description. I describe it, and the check clears. Colour Vision shows the card as someone with red-green colour blindness sees it, and it still works, because every change has an arrow and words, not just colour. Finally Shift-Command-C. Paste into Mail: rich text, a real table, the image. Paste into Slack: the same copy, and Slack picks the flavour it understands. One copy, the right format in each place.`,
  },
  {
    title: "One model, many renderers",
    minutes: 0.65,
    notes: `Three design principles. The first: one model, many renderers. A card is a plain value type with no UI dependencies, and every output is a pure function of it: the canvas you edit, the PNG and the PDF, inline-styled HTML for email, rich text for Mail, Markdown for Slack, plain text, even the spoken narration. That is why what you see is what you paste. It also makes a new destination cheap, and it lets the same code run without a window.`,
  },
  {
    title: "One package below, two consumers above",
    minutes: 1.1,
    notes: `Here is the shape of it, because the shape is the argument. At the bottom is one Swift package, ReportCore, that imports nothing but Foundation: the model, the parsers, every renderer, the accessibility linter and the templates. Two things sit on top, and neither knows the other exists: the Mac app, and a command-line tool. Dependencies point one way, and that single rule buys three things. The package's ninety tests run in under a second, so the renderers and the linter stay cheap to change. The same code runs headless, which is how accessibility became a gate in the pipeline. And it already builds for iOS, so an iPad version is a target rather than a rewrite. Inside the app it is Swift 6 with strict concurrency: a card is a Sendable value type, the stores are main-actor observable objects, and the compiler checks it.`,
  },
  {
    title: "Accessibility you can experience, not just pass",
    minutes: 0.95,
    notes: `The third principle is the one I care most about. Passing a checklist is the floor. Most people who write status reports do not use a screen reader, so they cannot tell what their report is like for someone who does. So the app lets you experience it. Hear This Card reads the card in the order and words a screen reader uses: heading level one, list of three items, velocity forty-two, up five percent, positive. If an image has no description, you hear the gap. Colour Vision shows the card under the common colour-vision deficiencies. And the linter checks fourteen rules as you type, each mapped to a WCAG criterion, including ones about language: it flags “the items marked in red”.`,
  },
  {
    title: "For those who read it, and those who write it",
    minutes: 0.65,
    notes: `Accessibility has two audiences. For people who receive a card: large print, which every export follows, and a tagged PDF with real text, headings and figure descriptions, so a screen reader treats it as a document rather than a picture. For people who use the app with VoiceOver: a metric's trend is an Audio Graph, so you hear the line as pitch; each block has move and delete actions, and a rotor jumps between blocks. The app honours the system's contrast, colour, transparency and motion settings.`,
  },
  {
    title: "New Card from Notes: the brief's first sentence",
    minutes: 0.9,
    notes: `I added one AI feature, because it answers the first sentence of the brief: quickly assemble and structure project progress. You paste rough notes, and the model returns a structured report: title, status, highlights, metrics, risks, next steps. What matters is what happens to the reply. It is treated as untrusted input: parsed defensively, every list bounded, the status mapped onto an enum, and then it goes through the same accessibility linter. The prompt forbids inventing numbers, nothing is saved until you press Create, and the sheet tells you to check every number. Refine does the same for one text block. I did not rebuild Writing Tools: with Apple Intelligence the system already provides them in every text field.`,
  },
  {
    title: "For this exercise only: not how I would ship it",
    minutes: 1.4,
    notes: `Now the part I want to be very clear about. In this demo the model is a public API, DeepSeek. That is for this exercise only. I would not ship it, and I would not use it with real data. Status reports are business data. Sent to a public third-party model they leave the organisation's control: the provider's retention and training terms apply, in the provider's jurisdiction, with no data-processing agreement, no security review and no audit trail. Pasted notes can carry a prompt injection, and a model can state a wrong number confidently. So why is it here? My Mac runs macOS 15, which cannot run Apple's on-device model, and a demo needs a model that answers. But the design assumes the right answer. The provider sits behind a protocol. The first implementation is Apple's Foundation Models, on device, where nothing leaves the Mac. The second is any compatible endpoint, which in a company means an approved internal gateway with authentication, redaction and logging. The feature is off by default, asks consent per host, and one build flag removes it with the network entitlement.`,
  },
  {
    title: "Fast where it is cheap, honest where it is not",
    minutes: 1.05,
    notes: `On testing, and the split is deliberate. Ninety tests in the package cover everything that is a pure function: parsers, renderers, contrast maths, the fourteen linter rules, and the parser that turns a model's reply into a card. They finish in under a second, so I run them constantly. Forty-seven app tests cover the store and undo, persistence, every export including the tagged PDF, and the assistant against a stubbed HTTP client. Twelve UI tests drive the real app, including XCTest's accessibility audit. Nothing touches your clipboard, your network or your files, with one deliberate exception: the Copy for Email test uses the real pasteboard, because the pasteboard is the thing under test. Three things I do not test, and say so instead: how Mail and Slack really render a paste, the VoiceOver experience, and PDF/UA conformance.`,
  },
  {
    title: "Built to be read and changed",
    minutes: 0.65,
    notes: `On the engineering around it. Configuration is not buried in the Xcode project: versions, feature flags and signing live in xcconfig files and reach the running app through one typed accessor. The project file is generated from a YAML spec, so a reviewer can read the build the way they read the code, and one flag removes writing assistance together with its network entitlement. There are no third-party dependencies. And twelve short decision records explain the choices someone might question, including the ones I reversed.`,
  },
  {
    title: "The cloud carries the software, not your data",
    minutes: 0.9,
    notes: `The brief mentions the cloud. A Mac app is distributed rather than hosted, and user data stays local on purpose, so what ships to the cloud is the software and its output. On every push, GitHub Actions runs the tests and lint. A push to main also renders a gallery of every template, with the same HTML renderer the app uses for email, and publishes it, but only if every card passes the linter in strict mode. Accessibility becomes a pipeline gate. A version tag is set up to build a release; I have not cut one yet. In an enterprise the same artifact would be notarised and distributed through Apple Business Manager or MDM.`,
  },
  {
    title: "What I would not claim yet",
    minutes: 0.7,
    notes: `I want to be straightforward about what I cannot claim. The on-device model path compiles behind availability checks, but I could not run it on macOS 15. The paste matrix separates what I verified by hand from what I expect from each app's documentation. The VoiceOver features are tested for their data; the experience needs someone who uses VoiceOver every day. The tagged PDF has a structure tree, but I have not run a PDF/UA validator. Next would be an iPad target on the same core, share links, and localisation.`,
  },
  {
    title: "Three things to take away",
    minutes: 0.5,
    notes: `Three things to take away. One model, many renderers: what you see is what you paste. Accessibility you can hear and see, not only pass, for the author, the reader and the VoiceOver user. And privacy as a design decision: local by default, AI opt-in, and honest about which parts are a demonstration. Thank you. I'd be glad to go deeper into any part.`,
  },
];
