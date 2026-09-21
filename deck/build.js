// Builds the presentation deck. Usage: node build.js [slideNumber]
// With a slide number it writes a one-slide deck (used for per-slide visual QA).
const fs = require("fs");
const path = require("path");
const pptxgen = require("pptxgenjs");
const NOTES = require("./notes.js");

const only = process.argv[2] ? Number(process.argv[2]) : null;
const ASSETS = path.join(__dirname, "assets");
const OUT = path.join(__dirname, only ? `qa/slide-${String(only).padStart(2, "0")}.pptx` : "Reporting-Builder.pptx");

const C = {
  ink: "1D1D1F", white: "FFFFFF", desk: "F5F5F7", grey: "6E6E73", line: "D2D2D7",
  accent: "0066CC", green: "248A3D", red: "D70015", amber: "C93400", darkCard: "2C2C2E", darkGrey: "A1A1A6",
};
// Ships with every Mac and sits closest to the system font; Arial has the same widths elsewhere.
const FONT = "Helvetica Neue";
const W = 13.333, H = 7.5, M = 0.7;

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE";
pres.author = "Tony Wen";
pres.title = "Reporting Builder";
pres.subject = "Project Reporting Builder: proof of concept";
pres.company = "";

let slideIndex = 0;
function newSlide(dark, notes) {
  slideIndex += 1;
  if (only && only !== slideIndex) return null;
  const slide = pres.addSlide();
  slide.background = { color: dark ? C.ink : C.desk };
  slide.addText(String(slideIndex), {
    x: W - 1.2, y: H - 0.5, w: 0.7, h: 0.3, fontFace: FONT, fontSize: 10, align: "right",
    color: dark ? C.darkGrey : C.grey, margin: 0, isTextBox: true,
  });
  if (notes) slide.addNotes(notes);
  return slide;
}
function title(slide, text, dark, opts = {}) {
  slide.addText(text, {
    x: M, y: 0.55, w: W - 2 * M, h: 0.9, fontFace: FONT, fontSize: opts.size || 34, bold: true,
    color: dark ? C.white : C.ink, margin: 0, valign: "top", isTextBox: true,
  });
}
function kicker(slide, text, dark) {
  slide.addText(text, {
    x: M, y: 0.3, w: W - 2 * M, h: 0.3, fontFace: FONT, fontSize: 12, bold: true, charSpacing: 1.5,
    color: dark ? C.darkGrey : C.grey, margin: 0, isTextBox: true,
  });
}
function card(slide, x, y, w, h, fill) {
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h, rectRadius: 0.18, fill: { color: fill || C.white }, line: { color: fill || C.white, width: 0 },
    shadow: { type: "outer", color: "000000", opacity: 0.10, blur: 12, offset: 3, angle: 90 },
  });
}
function text(slide, value, x, y, w, h, opts = {}) {
  slide.addText(value, Object.assign({
    x, y, w, h, fontFace: FONT, fontSize: 15, color: C.ink, margin: 0, valign: "top", isTextBox: true,
  }, opts));
}
function bullets(slide, items, x, y, w, h, opts = {}) {
  const runs = items.map((item, i) => ({
    text: item, options: { bullet: { indent: 16 }, breakLine: i < items.length - 1, paraSpaceAfter: opts.gap || 8 },
  }));
  slide.addText(runs, Object.assign({
    x, y, w, h, fontFace: FONT, fontSize: 15, color: C.ink, margin: 0, valign: "top", isTextBox: true,
  }, opts));
}
// Every picture must be described. PptxGenJS falls back to the file's absolute
// path when altText is missing, which both leaks a local path and reads out as
// the alternative text; a deck about accessibility cannot ship that.
function image(slide, file, x, y, w, h, alt) {
  if (!alt || alt.length < 12) throw new Error(`describe the image ${file}`);
  const full = path.join(ASSETS, file);
  if (!fs.existsSync(full)) { console.warn("missing asset", file); return; }
  slide.addImage({ path: full, x, y, w, h, sizing: { type: "contain", w, h }, altText: alt, objectName: file });
}
function dot(slide, x, y, color) {
  slide.addShape(pres.shapes.OVAL, { x, y, w: 0.16, h: 0.16, fill: { color }, line: { color, width: 0 } });
}

// ---------------------------------------------------------------- 1 Title
{
  const s = newSlide(true, NOTES[0].notes);
  if (s) {
    image(s, "app-icon.png", M, 1.5, 1.5, 1.5, "The app icon: a blue document card on a white rounded plate.");
    text(s, "Reporting Builder", M, 3.3, 9, 1, { fontSize: 50, bold: true, color: C.white });
    text(s, "From raw notes to an accessible status card, in the tools your team already uses.", M, 4.35, 9.5, 0.9, { fontSize: 22, color: C.darkGrey });
    text(s, "Tony Wen  ·  Project Reporting Builder  ·  Proof of concept", M, 6.3, 9, 0.4, { fontSize: 14, color: C.darkGrey });
  }
}

// ---------------------------------------------------------------- 2 Problem
{
  const s = newSlide(false, NOTES[1].notes);
  if (s) {
    kicker(s, "THE PROBLEM");
    title(s, "Every week, the same update, three times");
    const cols = [
      ["Scattered inputs", "Points in a notes app, numbers in a spreadsheet, a chart as a screenshot. Nothing is in one place or one format."],
      ["Redone per channel", "Mail wants rich text, Slack wants its own markup, the wiki wants Markdown. Each copy is made by hand."],
      ["Accessibility last", "Images without descriptions, status shown by colour alone, text trapped inside screenshots. Nobody checks."],
    ];
    const cw = (W - 2 * M - 2 * 0.4) / 3;
    cols.forEach((c, i) => {
      const x = M + i * (cw + 0.4);
      card(s, x, 1.9, cw, 3.6);
      text(s, String(i + 1), x + 0.4, 2.2, 1, 0.8, { fontSize: 40, bold: true, color: C.accent });
      text(s, c[0], x + 0.4, 3.1, cw - 0.8, 0.5, { fontSize: 20, bold: true });
      text(s, c[1], x + 0.4, 3.7, cw - 0.8, 1.6, { fontSize: 15, color: C.grey });
    });
    text(s, "The brief: ingest text, metrics and images; produce modular, polished, accessible cards; copy or export them instantly.", M, 5.95, W - 2 * M, 0.7, { fontSize: 16, italic: true, color: C.ink });
  }
}

// ---------------------------------------------------------------- 3 What I built
{
  const s = newSlide(false, NOTES[2].notes);
  if (s) {
    kicker(s, "WHAT I BUILT");
    title(s, "A Mac app where the card is the document");
    card(s, M, 1.6, 8.3, 5.2);
    image(s, "hero.png", M + 0.15, 1.75, 8.0, 4.9, "The app window: a list of cards on the left, a weekly status card being edited in the middle, and the Format inspector on the right showing themes, text size, status and width.");
    const x = M + 8.7, w = W - x - M;
    text(s, "In", x, 1.7, w, 0.35, { fontSize: 13, bold: true, color: C.grey });
    text(s, "Type on the card, paste a spreadsheet range, drop files. Smart Paste picks the block type.", x, 2.05, w, 1.0, { fontSize: 15 });
    text(s, "Card", x, 3.25, w, 0.35, { fontSize: 13, bold: true, color: C.grey });
    text(s, "Text, metrics and image blocks. Four themes, large print, fourteen accessibility checks as you type.", x, 3.6, w, 1.0, { fontSize: 15 });
    text(s, "Out", x, 4.8, w, 0.35, { fontSize: 13, bold: true, color: C.grey });
    text(s, "One shortcut copies for Mail, Notes and Slack. PNG, tagged PDF, HTML, Markdown, print, share, drag out.", x, 5.15, w, 1.2, { fontSize: 15 });
  }
}

// ---------------------------------------------------------------- 4 Demo
{
  const s = newSlide(true, NOTES[3].notes);
  if (s) {
    kicker(s, "LIVE DEMO  ·  3 MINUTES", true);
    title(s, "From scattered inputs to a shared card", true);
    const steps = [
      "New card from a template; type on the card",
      "Paste a spreadsheet range: metrics with change arrows",
      "Drop a screenshot: the shield turns red, “Add Description”",
      "Hear This Card: “Image. No description.” Describe it; it clears",
      "Colour Vision: still readable without red and green",
      "⇧⌘C, paste into Mail, then into Slack",
    ];
    steps.forEach((t, i) => {
      const y = 1.75 + i * 0.78;
      s.addShape(pres.shapes.OVAL, { x: M, y, w: 0.5, h: 0.5, fill: { color: C.darkCard }, line: { color: C.darkCard, width: 0 } });
      text(s, String(i + 1), M, y + 0.08, 0.5, 0.34, { fontSize: 15, bold: true, color: C.white, align: "center" });
      text(s, t, M + 0.75, y + 0.07, 5.6, 0.45, { fontSize: 16, color: C.white });
    });
    image(s, "missing.png", 7.3, 1.7, W - 7.3 - M, 4.9, "The same card after a chart is dropped in: the toolbar shield is red, the image carries an Add Description button, and the Accessibility tab reports one error.");
  }
}

// ---------------------------------------------------------------- 5 Principle 1
{
  const s = newSlide(false, NOTES[4].notes);
  if (s) {
    kicker(s, "PRINCIPLE 1");
    title(s, "One model, many renderers");
    const cx = 5.0, cy = 3.24, cw = 3.3, ch = 1.5; // centre y = 3.99, level with the middle cards
    card(s, cx, cy, cw, ch, C.ink);
    text(s, "SnippetCard", cx, cy + 0.32, cw, 0.45, { fontSize: 22, bold: true, color: C.white, align: "center" });
    text(s, "value type · Codable · Sendable", cx, cy + 0.85, cw, 0.35, { fontSize: 12, color: C.darkGrey, align: "center" });
    const outs = [
      ["Canvas, PNG, tagged PDF", "SwiftUI"], ["Email HTML, web page", "inline styles, semantic"], ["Rich text", "Mail, Notes"],
      ["Markdown, Slack", "chat and wiki"], ["Plain text", "Messages, fallback"], ["Spoken narration", "Hear This Card"],
    ];
    outs.forEach((o, i) => {
      const left = i < 3;
      const x = left ? M : W - M - 3.6;
      const y = 1.75 + (i % 3) * 1.62;
      card(s, x, y, 3.6, 1.25);
      text(s, o[0], x + 0.3, y + 0.25, 3.0, 0.4, { fontSize: 16, bold: true });
      text(s, o[1], x + 0.3, y + 0.7, 3.0, 0.35, { fontSize: 13, color: C.grey });
      const cardY = y + 0.625, hubY = cy + ch / 2;
      // Left cards run card -> hub, right cards run hub -> card; flip when that direction climbs.
      const climbs = left ? cardY > hubY : cardY < hubY;
      s.addShape(pres.shapes.LINE, {
        x: left ? x + 3.6 : cx + cw, y: Math.min(cardY, hubY), w: left ? cx - (x + 3.6) : x - (cx + cw), h: Math.abs(cardY - hubY),
        line: { color: C.line, width: 1.5 }, flipV: climbs,
      });
    });
    text(s, "Also on the same model: accessibility linter · templates · JSON import/export · reportcard CLI", M, 6.65, W - 2 * M, 0.4, { fontSize: 14, color: C.grey, align: "center" });
  }
}

// ---------------------------------------------------------------- 6 Architecture
{
  const s = newSlide(false, NOTES[5].notes);
  if (s) {
    kicker(s, "ARCHITECTURE");
    title(s, "One package below, two consumers above");
    const inner = W - 2 * M;
    const aw = 7.3, bx = M + aw + 0.4, bw = W - M - bx;

    card(s, M, 1.55, aw, 1.3);
    text(s, "Reporting Builder.app", M + 0.35, 1.78, aw - 0.7, 0.4, { fontSize: 18, bold: true });
    text(s, "SwiftUI + AppKit · Store · Workspace · Canvas · Inspector · Export · Assistant", M + 0.35, 2.24, aw - 0.7, 0.5, { fontSize: 13, color: C.grey });

    card(s, bx, 1.55, bw, 1.3);
    text(s, "reportcard", bx + 0.35, 1.78, bw - 0.7, 0.4, { fontSize: 18, bold: true });
    text(s, "a command-line tool · render · lint · site", bx + 0.35, 2.24, bw - 0.7, 0.5, { fontSize: 13, color: C.grey });

    text(s, "↓  imports", M, 3.0, aw, 0.35, { fontSize: 13, color: C.grey, align: "center" });
    text(s, "↓  imports", bx, 3.0, bw, 0.35, { fontSize: 13, color: C.grey, align: "center" });

    card(s, M, 3.5, inner, 1.5, C.ink);
    text(s, "ReportCore", M + 0.45, 3.72, inner - 0.9, 0.45, { fontSize: 22, bold: true, color: C.white });
    text(s, "a Swift package that imports only Foundation", M + 0.45, 4.18, inner - 0.9, 0.35, { fontSize: 13, color: C.darkGrey });
    text(s, "Model · Ingestion · Rendering · Accessibility linter · Templates · Assistant prompts", M + 0.45, 4.52, inner - 0.9, 0.4, { fontSize: 15, color: C.white });

    const pts = [
      ["Dependencies point one way", "ReportCore has never heard of SwiftUI, AppKit or the network, and nothing below it imports anything above."],
      ["Testable without a window", "Its ninety tests run in under a second, so the renderers and the linter stay cheap to change."],
      ["One target away from iPad", "The package builds for iOS too. Only the views are specific to the Mac."],
    ];
    const pw = (inner - 2 * 0.4) / 3;
    pts.forEach((p, i) => {
      const x = M + i * (pw + 0.4);
      text(s, p[0], x, 5.35, pw, 0.35, { fontSize: 16, bold: true });
      text(s, p[1], x, 5.76, pw, 1.0, { fontSize: 13.5, color: C.grey });
    });
    text(s, "Swift 6 language mode throughout: a card is a Sendable value type, and the stores are main-actor observable objects.", M, 6.8, inner, 0.4, { fontSize: 13, italic: true, color: C.grey });
  }
}

// ---------------------------------------------------------------- 7 Principle 3
{
  const s = newSlide(false, NOTES[6].notes);
  if (s) {
    kicker(s, "PRINCIPLE 3");
    title(s, "Accessibility you can experience, not just pass");
    const cw = (W - 2 * M - 2 * 0.4) / 3;
    const cols = [
      ["Hear This Card", "Spoken the way a screen reader presents it, block by block. A missing description is a silence you can hear.", "listen-crop.png", "The spoken transcript: each line as a screen reader would say it, the line being read marked with a speaker glyph, and “Image. No description.” in red."],
      ["Colour Vision", "Protanopia, deuteranopia, tritanopia, no colour. Status and changes still read, because they are shapes and words.", "cvd-crop.png", "The card simulated as seen with deuteranopia: the green and red of the status and the change arrows are gone, but the arrows, the words and the numbers still carry the meaning."],
      ["Fourteen checks, live", "Contrast, alt text, labels, headings, and language: “the red items”, long capitals, images that are mostly text (on-device OCR).", "checks-crop.png", "The Accessibility tab reporting Needs Attention with one error, and the issue beneath it: describe this image for people who cannot see it, or mark it decorative, citing WCAG 1.1.1."],
    ];
    cols.forEach((c, i) => {
      const x = M + i * (cw + 0.4);
      card(s, x, 1.65, cw, 5.2);
      image(s, c[2], x + 0.15, 1.8, cw - 0.3, 3.0, c[3]);
      text(s, c[0], x + 0.35, 5.0, cw - 0.7, 0.4, { fontSize: 18, bold: true });
      text(s, c[1], x + 0.35, 5.45, cw - 0.7, 1.3, { fontSize: 13.5, color: C.grey });
    });
  }
}

// ---------------------------------------------------------------- 8 Readers + VoiceOver
{
  const s = newSlide(false, NOTES[7].notes);
  if (s) {
    kicker(s, "ACCESSIBILITY, CONTINUED");
    title(s, "For those who read it, and those who write it");
    const left = [
      ["Large print", "Standard, Large, Extra Large. HTML, rich text, PNG and PDF all follow."],
      ["Tagged PDF", "Real text, H1/H2, lists, figures with alt text, document metadata."],
      ["Semantic email HTML", "Headings, table header scopes, hidden words for ▲ and ▼, status never by colour alone."],
    ];
    const right = [
      ["Audio Graph", "A metric's trend plays as pitch through AXChartDescriptor, as in Stocks and Health."],
      ["Rotor and actions", "A Blocks rotor; Move Up, Move Down, Format, Delete on every block."],
      ["System settings honoured", "Differentiate Without Colour, Increase Contrast, Reduce Transparency, Reduce Motion. Undo and Redo."],
    ];
    const cw = (W - 2 * M - 0.5) / 2;
    [[left, M, "For the reader"], [right, M + cw + 0.5, "For VoiceOver and keyboard users"]].forEach(([items, x, heading]) => {
      card(s, x, 1.65, cw, 5.15);
      text(s, heading, x + 0.4, 1.95, cw - 0.8, 0.4, { fontSize: 13, bold: true, color: C.grey });
      items.forEach((it, i) => {
        const y = 2.6 + i * 1.35;
        dot(s, x + 0.42, y + 0.1, C.accent);
        text(s, it[0], x + 0.8, y, cw - 1.2, 0.4, { fontSize: 17, bold: true });
        text(s, it[1], x + 0.8, y + 0.42, cw - 1.2, 0.8, { fontSize: 13.5, color: C.grey });
      });
    });
  }
}

// ---------------------------------------------------------------- 9 AI feature
{
  const s = newSlide(false, NOTES[8].notes);
  if (s) {
    kicker(s, "AI ASSISTANCE  ·  OPT-IN");
    title(s, "New Card from Notes: the brief's first sentence");
    card(s, M, 1.65, 7.4, 5.15);
    image(s, "draft.png", M + 0.15, 1.8, 7.1, 4.85, "New Card from Notes: rough meeting notes on the left, and on the right the drafted card with a title, status, summary, highlights, metrics, risks and next steps, above a line saying all fourteen accessibility checks passed.");
    const x = M + 7.8, w = W - x - M;
    bullets(s, [
      "Rough notes in; title, status, highlights, metrics, risks, next steps out",
      "The reply is untrusted input: parsed, bounded, mapped, then linted",
      "Nothing is saved until Create; “check every number”",
      "Refine a text block: concise, formal, grammar. One undo step",
      "Not rebuilt: the system's Writing Tools already work in every field",
    ], x, 1.75, w, 4.6, { fontSize: 15, gap: 12 });
    text(s, "Provider-agnostic: on-device first", x, 6.25, w, 0.4, { fontSize: 14, bold: true, color: C.accent });
  }
}

// ---------------------------------------------------------------- 10 AI risk
{
  const s = newSlide(false, NOTES[9].notes);
  if (s) {
    kicker(s, "AI ASSISTANCE  ·  DATA RISK");
    title(s, "For this exercise only: not how I would ship it");
    card(s, M, 1.6, W - 2 * M, 1.05, "FFF1F0");
    text(s, "Sending real project data to a public third-party model is not acceptable in a real business setting. The demo uses a public API only because my Mac (macOS 15) cannot run the on-device model.", M + 0.4, 1.78, W - 2 * M - 0.8, 0.75, { fontSize: 15.5, bold: true, color: "8A0F14" });
    const cw = (W - 2 * M - 0.5) / 2;
    card(s, M, 2.9, cw, 3.95);
    text(s, "Why it is a risk", M + 0.4, 3.1, cw - 0.8, 0.4, { fontSize: 17, bold: true, color: C.red });
    bullets(s, [
      "Confidentiality: plans, names, financials, incidents leave the organisation",
      "Provider's retention and training terms, provider's jurisdiction",
      "No DPA, vendor security review, data residency or audit trail",
      "Prompt injection via pasted notes; confident wrong numbers",
      "A personal API key on a laptop is not an enterprise credential",
    ], M + 0.4, 3.6, cw - 0.8, 3.1, { fontSize: 13.5, gap: 6 });
    card(s, M + cw + 0.5, 2.9, cw, 3.95);
    text(s, "What I would ship instead", M + cw + 0.9, 3.1, cw - 0.8, 0.4, { fontSize: 17, bold: true, color: C.green });
    bullets(s, [
      "On-device first: Apple Foundation Models, nothing leaves the Mac",
      "Otherwise an approved internal gateway: auth, redaction/DLP, logging",
      "Already built: endpoint and model are configuration, not code",
      "Already built: off by default, consent per host, key in the Keychain, HTTPS only",
      "Already built: one build flag removes the feature and the network entitlement",
    ], M + cw + 0.9, 3.6, cw - 0.8, 3.1, { fontSize: 13.5, gap: 6 });
  }
}

// ---------------------------------------------------------------- 11 Testing
{
  const s = newSlide(false, NOTES[10].notes);
  if (s) {
    kicker(s, "TESTING");
    title(s, "Fast where it is cheap, honest where it is not");
    const inner = W - 2 * M;
    const levels = [
      ["90", "core unit tests", "Parsers, renderers, contrast maths, the fourteen linter rules, the draft parser. Under one second."],
      ["47", "app unit tests", "Store and undo, persistence, every export including the tagged PDF, pasteboard types, smart paste."],
      ["12", "UI tests", "Canvas, inspector, the undescribed image, Hear This Card, Colour Vision, drafting, and XCTest's accessibility audit."],
      ["2", "static checks", "SwiftLint and SwiftFormat, clean, on every push alongside the tests."],
    ];
    const lw = (inner - 3 * 0.35) / 4;
    levels.forEach((l, i) => {
      const x = M + i * (lw + 0.35);
      card(s, x, 1.55, lw, 2.45);
      text(s, l[0], x + 0.3, 1.72, lw - 0.6, 0.75, { fontSize: 40, bold: true, color: C.accent });
      text(s, l[1], x + 0.3, 2.46, lw - 0.6, 0.35, { fontSize: 15, bold: true });
      text(s, l[2], x + 0.3, 2.86, lw - 0.6, 1.0, { fontSize: 12.5, color: C.grey });
    });
    const cw = (inner - 0.5) / 2;
    card(s, M, 4.25, cw, 2.6);
    text(s, "Kept deterministic", M + 0.4, 4.45, cw - 0.8, 0.4, { fontSize: 17, bold: true });
    bullets(s, [
      "Never the real clipboard, network or files: named pasteboards, temporary directories, an in-memory store, a stubbed client",
      "One exception, on purpose: the Copy for Email test uses the real pasteboard, because that is what it tests",
      "Dates and locale are injected, so a footer never depends on the test machine",
      "Launch arguments open the app in a known state: a seeded card, a missing description, a canned model",
    ], M + 0.4, 4.88, cw - 0.8, 1.95, { fontSize: 12.5, gap: 4 });
    card(s, M + cw + 0.5, 4.25, cw, 2.6);
    text(s, "Not covered by a test, and said so", M + cw + 0.9, 4.45, cw - 0.8, 0.4, { fontSize: 17, bold: true });
    bullets(s, [
      "How Mail and Slack actually render a paste: each destination is marked verified or expected in the docs",
      "The VoiceOver experience: the data is tested, the experience needs a person who uses it daily",
      "PDF/UA conformance: the structure tree is checked, a validator is not run",
      "Each of these sits in the documentation next to the feature it limits",
    ], M + cw + 0.9, 4.88, cw - 0.8, 1.95, { fontSize: 12.5, gap: 4 });
  }
}

// ---------------------------------------------------------------- 12 Engineering
{
  const s = newSlide(false, NOTES[11].notes);
  if (s) {
    kicker(s, "ENGINEERING");
    title(s, "Built to be read and changed");
    const stats = [["0", "third-party dependencies"], ["12", "architecture decision records"], ["4", "feature flags, set in xcconfig"], ["1", "YAML spec generates the Xcode project"]];
    const sw = (W - 2 * M - 3 * 0.35) / 4;
    stats.forEach((st, i) => {
      const x = M + i * (sw + 0.35);
      card(s, x, 1.65, sw, 1.95);
      text(s, st[0], x + 0.3, 1.85, sw - 0.6, 0.9, { fontSize: 44, bold: true, color: C.accent });
      text(s, st[1], x + 0.3, 2.8, sw - 0.6, 0.7, { fontSize: 13, color: C.grey });
    });
    const cw = (W - 2 * M - 0.5) / 2;
    card(s, M, 3.95, cw, 2.9);
    text(s, "Code", M + 0.4, 4.15, cw - 0.8, 0.4, { fontSize: 13, bold: true, color: C.grey });
    bullets(s, [
      "Documented public API; comments say why, not what",
      "Model replies are untrusted input: parsed, bounded, linted",
      "One concern per type; the compiler lists every place a new block kind touches",
      "Conventional commits, one change each, readable in order",
    ], M + 0.4, 4.6, cw - 0.8, 2.2, { fontSize: 14, gap: 6 });
    card(s, M + cw + 0.5, 3.95, cw, 2.9);
    text(s, "Configuration and delivery", M + cw + 0.9, 4.15, cw - 0.8, 0.4, { fontSize: 13, bold: true, color: C.grey });
    bullets(s, [
      "Versions, flags and signing live in xcconfig, not buried in the project file",
      "XcodeGen writes the .xcodeproj from YAML, so the build is reviewable",
      "One flag removes writing assistance and its network entitlement",
      "GitHub Actions on every push: tests, SwiftLint, SwiftFormat, CLI smoke test",
    ], M + cw + 0.9, 4.6, cw - 0.8, 2.2, { fontSize: 14, gap: 6 });
  }
}

// ---------------------------------------------------------------- 13 Cloud
{
  const s = newSlide(false, NOTES[12].notes);
  if (s) {
    kicker(s, "CLOUD AND DELIVERY");
    title(s, "The cloud carries the software, not your data");
    const steps = [["git push", "every commit"], ["Tests + lint", "GitHub Actions"], ["reportcard lint", "accessibility gate"], ["Pages gallery", "same HTML renderer"]];
    const sw = (W - 2 * M - 3 * 0.55) / 4;
    steps.forEach((st, i) => {
      const x = M + i * (sw + 0.55);
      card(s, x, 1.75, sw, 1.35, i === 2 ? C.ink : C.white);
      text(s, st[0], x + 0.25, 1.98, sw - 0.5, 0.45, { fontSize: 16, bold: true, color: i === 2 ? C.white : C.ink });
      text(s, st[1], x + 0.25, 2.48, sw - 0.5, 0.4, { fontSize: 12.5, color: i === 2 ? C.darkGrey : C.grey });
      if (i < 3) text(s, "→", x + sw + 0.08, 2.1, 0.4, 0.5, { fontSize: 22, color: C.grey, align: "center" });
    });
    card(s, M, 3.45, 6.3, 3.4);
    image(s, "gallery-fade.png", M + 0.12, 3.57, 6.06, 3.16, "The published card gallery page, showing the weekly status and milestone templates rendered by the same HTML renderer the app uses for email.");
    const x = M + 6.75, w = W - x - M;
    bullets(s, [
      "User data stays on the Mac by design",
      "Release workflow on a version tag: zipped app and checksum",
      "Headless CLI: render from JSON, lint in any pipeline",
      "Enterprise path: notarise, then Apple Business Manager or MDM",
      "Next: share links via CloudKit or an internal Swift service; the renderers do not change",
    ], x, 3.55, w - 0.25, 3.3, { fontSize: 14, gap: 8 });
  }
}

// ---------------------------------------------------------------- 14 Trade-offs
{
  const s = newSlide(false, NOTES[13].notes);
  if (s) {
    kicker(s, "TRADE-OFFS");
    title(s, "What I would not claim yet");
    const cw = (W - 2 * M - 0.5) / 2;
    card(s, M, 1.65, cw, 4.1);
    text(s, "Not verified, and documented as such", M + 0.4, 1.9, cw - 0.8, 0.4, { fontSize: 17, bold: true });
    bullets(s, [
      "On-device model: compiles with availability checks, not run (my Mac is on macOS 15)",
      "Paste targets: “verified” and “expected” are kept apart in the docs",
      "VoiceOver features: data is tested, the experience needs a human",
      "Tagged PDF: structure tree present, not validated against PDF/UA",
      "Ad-hoc signed; notarisation needs a Developer ID",
    ], M + 0.4, 2.45, cw - 0.8, 3.2, { fontSize: 14, gap: 9 });
    card(s, M + cw + 0.5, 1.65, cw, 4.1);
    text(s, "Deliberate limits and next steps", M + cw + 0.9, 1.9, cw - 0.8, 0.4, { fontSize: 17, bold: true });
    bullets(s, [
      "Tiny text markup on purpose, so every renderer agrees",
      "Rich text has no alt text: Mail gets the caption; HTML and PDF keep the description",
      "Colour-vision matrices are an approximation, not a clinical tool",
      "Next: iPad target on the same core, share links, localisation",
    ], M + cw + 0.9, 2.45, cw - 0.8, 3.2, { fontSize: 14, gap: 9 });
    text(s, "Each of these is written down in the repository, next to the feature it limits: the paste matrix, the accessibility notes and the decision records.", M, 6.1, W - 2 * M, 0.7, { fontSize: 16, italic: true });
  }
}

// ---------------------------------------------------------------- 15 Close
{
  const s = newSlide(true, NOTES[14].notes);
  if (s) {
    title(s, "Three things to take away", true, { size: 38 });
    const items = [
      ["One model, many renderers", "What you see is what you paste, in every channel."],
      ["Accessibility you can hear and see", "For the author, the reader, and the VoiceOver user."],
      ["Privacy is a design decision", "Local by default, AI opt-in, and honest about what is a demo."],
    ];
    items.forEach((it, i) => {
      const y = 2.0 + i * 1.35;
      text(s, String(i + 1), M, y - 0.05, 0.8, 0.9, { fontSize: 44, bold: true, color: C.accent });
      text(s, it[0], M + 1.0, y, 10, 0.5, { fontSize: 24, bold: true, color: C.white });
      text(s, it[1], M + 1.0, y + 0.55, 10, 0.45, { fontSize: 16, color: C.darkGrey });
    });
    text(s, "Thank you. Questions?", M, 6.3, 8, 0.5, { fontSize: 20, bold: true, color: C.white });
    text(s, "github.com/ANTI-Tony/apple_oa  ·  anti-tony.github.io/apple_oa", M, 6.8, 10, 0.35, { fontSize: 13, color: C.darkGrey });
  }
}

fs.mkdirSync(path.dirname(OUT), { recursive: true });
pres.writeFile({ fileName: OUT }).then(() => console.log("wrote", OUT));
