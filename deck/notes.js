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
    minutes: 0.75,
    notes: `Think of a program manager on a Thursday afternoon. The material for the weekly update is scattered: bullet points in a notes app, numbers in a spreadsheet, a chart as a screenshot. They assemble it for email, then again for Slack, then again for the wiki. And nothing ever asks: can a colleague with a screen reader read this? Does the status still make sense without red and green? Three problems: assembling, re-formatting, and accessibility arriving too late, or never.`,
  },
  {
    title: "A Mac app where the card is the document",
    minutes: 0.75,
    notes: `This is Reporting Builder, a native Mac app in Swift and SwiftUI. On the left, your cards. In the middle, the card itself, and that is the editor: you click the title and type, as in Pages or Keynote. On the right, a Format inspector for what you can't see on the card: theme, layout, image descriptions, and the accessibility check. Why native rather than web? Copy and share are the product, and the Mac pasteboard can carry rich text, HTML and plain text at once. And accessibility is a platform feature here, not an add-on.`,
  },
  {
    title: "From scattered inputs to a shared card",
    minutes: 3,
    notes: `Let me show you. I start a weekly status from a template and type straight onto the card. Now I copy a range from a spreadsheet and press Shift-Command-V. It recognises a table and offers metrics, with the change computed, and it knows that fewer open bugs is good news. I drop in a screenshot. The shield in the toolbar turns red, and the image asks for a description. Before I fix it, listen. [Play Hear This Card.] That's what a colleague with a screen reader gets: Image, no description. I describe it, and the check clears. Colour Vision shows the card as someone with red-green colour blindness sees it, and it still works, because every change has an arrow and words, not just colour. Finally Shift-Command-C. Paste into Mail: rich text, a real table, the image. Paste into Slack: the same copy, and Slack picks the flavour it understands. One copy, the right format in each place.`,
  },
  {
    title: "One model, many renderers",
    minutes: 0.75,
    notes: `Three design principles. First: one model, many renderers. A card is a plain value type in a Swift package with no UI dependencies. Every output is a pure function of it: the canvas you edit, the PNG and PDF, inline-styled HTML for email, rich text for Mail and Notes, Markdown for Slack, plain text, even the spoken narration. That's why what you see is what you paste. It also makes a new destination cheap, and it lets the same code run without a window: a command-line tool renders and lints cards in CI.`,
  },
  {
    title: "The card is the editor",
    minutes: 0.9,
    notes: `The second principle came from throwing my first interface away. Version one, on the left, was a form beside a live preview. It worked, but you described the card in one place and looked at it in another, and the card looked like a dashboard: capital-letter labels, coloured pills, boxed tiles. So I rebuilt it the way Pages and Keynote work. The card is the editor, and properties live in a Format inspector. The card became typographic: one large title, sentence-case headings, status as words beside a small indicator. Both versions are in the repository history, with the decision written down.`,
  },
  {
    title: "Accessibility you can experience, not just pass",
    minutes: 1,
    notes: `The third principle is the one I care most about. Passing a checklist is the floor. Most people who write status reports don't use a screen reader, so they can't tell what their report is like for someone who does. So the app lets you experience it. Hear This Card reads the card in the order and words a screen reader uses: heading level one, list of three items, velocity forty-two, up five percent, positive. If an image has no description, you hear the gap. Colour Vision shows the card under the common colour-vision deficiencies. And the linter checks fourteen rules as you type, each mapped to a WCAG criterion. Some are about language: it flags "the items marked in red", and it notices an image that is really a picture of text.`,
  },
  {
    title: "For those who read it, and those who write it",
    minutes: 0.9,
    notes: `Accessibility has two audiences. For people who receive a card: large print, which every export follows, and a tagged PDF with real text, headings and figure descriptions, so a screen reader treats it as a document, not a picture. For people who use the app with VoiceOver: a metric's trend is an Audio Graph, so you hear the line as pitch, as in Stocks and Health; each block has move and delete actions, and a rotor jumps between blocks. The app honours the system's contrast, colour, transparency and motion settings, and structural edits have named Undo steps.`,
  },
  {
    title: "New Card from Notes: the brief's first sentence",
    minutes: 1,
    notes: `I added one AI feature, because it answers the first sentence of the brief: quickly assemble and structure project progress. You paste rough notes, and the model returns a structured report: title, status, highlights, metrics, risks, next steps. What matters is what happens to the reply. It's treated as untrusted input: parsed defensively, every list bounded, the status mapped onto an enum, and then it goes through the same accessibility linter. The prompt forbids inventing numbers, nothing is saved until you press Create, and the sheet tells you to check every number. Refine does the same for one text block: concise, formal, or fix grammar. I did not rebuild Writing Tools: with Apple Intelligence, the system provides them in every text field.`,
  },
  {
    title: "For this exercise only: not how I would ship it",
    minutes: 1.4,
    notes: `Now the part I want to be very clear about. In this demo the model is a public API, DeepSeek. That is for this exercise only. I would not ship it, and I would not use it with real data. Status reports are business data. Sent to a public third-party model, they leave the organisation's control: the provider's retention and training terms apply, in the provider's jurisdiction, with no data-processing agreement, no security review and no audit trail. Pasted notes can carry a prompt injection, and a model can state a wrong number confidently. So why is it there? My Mac runs macOS 15, which can't run Apple's on-device model, and a demo needs a model that answers. But the design assumes the right answer. The provider sits behind a protocol. The first implementation is Apple's Foundation Models, on device, where nothing leaves the Mac. The second is any compatible endpoint, which in a company means an approved internal gateway with authentication, redaction and logging. The feature is off by default, asks consent per host, keeps the key in the Keychain, and one build flag removes it with the network entitlement.`,
  },
  {
    title: "Built to be read, tested and changed",
    minutes: 0.9,
    notes: `On engineering. The domain logic is a Swift package with no UI imports, so its tests run in about a second. Everything compiles in Swift 6 mode with strict concurrency. There are about a hundred and forty unit tests: parsers, renderers and the linter in the package; export, the pasteboard, undo, and the assistant against a stubbed network in the app. On top sit UI tests that include XCTest's accessibility audit. Configuration lives in xcconfig files and reaches runtime as feature flags. Lint is clean, CI runs on every push, and there are no third-party dependencies. Twelve short decision records explain the choices someone might question, including the ones I reversed.`,
  },
  {
    title: "The cloud carries the software, not your data",
    minutes: 0.9,
    notes: `The brief mentions the cloud. A Mac app is distributed rather than hosted, and I keep user data local on purpose. So what goes to the cloud is the software and its output. On every push, GitHub Actions runs tests and lint. A push to main also renders a gallery of every template with the same HTML renderer the app uses for email, and publishes it to GitHub Pages, but only if every card passes the accessibility linter in strict mode. Accessibility becomes a pipeline gate. A version tag is set up to build a release; I have not cut one yet. In an enterprise, the same artifact would be notarised and distributed through Apple Business Manager or MDM.`,
  },
  {
    title: "What I would not claim yet",
    minutes: 0.9,
    notes: `I want to be straightforward about what I can't claim. The on-device model path compiles behind availability checks, but I couldn't run it on macOS 15. The paste matrix separates what I verified by hand from what I expect from each app's documentation. The VoiceOver features are tested for their data, but the experience needs someone who uses VoiceOver every day. The tagged PDF has a structure tree, but I haven't run a PDF/UA validator. And rich text has no alt text, so an image pasted into Mail carries its caption, not its description. Next would be an iPad target on the same core, share links, and localisation.`,
  },
  {
    title: "Three things to take away",
    minutes: 0.5,
    notes: `Three things to take away. One model, many renderers: what you see is what you paste. Accessibility you can hear and see, not only pass, for the author, the reader and the VoiceOver user. And privacy as a design decision: local by default, AI opt-in, and honest about which parts are a demonstration. Thank you. I'd be glad to go deeper into any part.`,
  },
];
