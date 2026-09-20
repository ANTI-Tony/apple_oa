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
function image(slide, file, x, y, w, h) {
  const full = path.join(ASSETS, file);
  if (!fs.existsSync(full)) { console.warn("missing asset", file); return; }
  slide.addImage({ path: full, x, y, w, h, sizing: { type: "contain", w, h } });
}
function dot(slide, x, y, color) {
  slide.addShape(pres.shapes.OVAL, { x, y, w: 0.16, h: 0.16, fill: { color }, line: { color, width: 0 } });
}

// ---------------------------------------------------------------- 1 Title
{
  const s = newSlide(true, NOTES[0].notes);
  if (s) {
    image(s, "app-icon.png", M, 1.5, 1.5, 1.5);
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
    image(s, "hero.png", M + 0.15, 1.75, 8.0, 4.9);
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
    image(s, "missing.png", 7.3, 1.7, W - 7.3 - M, 4.9);
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

// ---------------------------------------------------------------- 6 Principle 2
{
  const s = newSlide(false, NOTES[5].notes);
  if (s) {
    kicker(s, "PRINCIPLE 2");
    title(s, "The card is the editor");
    const iw = (W - 2 * M - 0.5) / 2;
    card(s, M, 1.65, iw, 3.95);
    image(s, "before.png", M + 0.12, 1.77, iw - 0.24, 3.4);
    text(s, "Version 1: form + preview", M + 0.3, 5.25, iw - 0.6, 0.3, { fontSize: 13, bold: true, color: C.grey });
    card(s, M + iw + 0.5, 1.65, iw, 3.95);
    image(s, "hero.png", M + iw + 0.62, 1.77, iw - 0.24, 3.4);
    text(s, "Version 2: canvas + Format inspector", M + iw + 0.8, 5.25, iw - 0.6, 0.3, { fontSize: 13, bold: true, color: C.accent });
    bullets(s, [
      "Direct manipulation: click the title and type, as in Pages and Keynote",
      "What is not visible on the card lives in an inspector: theme, layout, image description",
      "Typographic card: hierarchy from size and weight, not boxes, capitals or colour",
    ], M + 0.15, 5.9, W - 2 * M - 0.15, 1.3, { fontSize: 15, gap: 4 });
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
      ["Hear This Card", "Spoken the way a screen reader presents it, block by block. A missing description is a silence you can hear.", "listen-crop.png"],
      ["Colour Vision", "Protanopia, deuteranopia, tritanopia, no colour. Status and changes still read, because they are shapes and words.", "cvd-crop.png"],
      ["Fourteen checks, live", "Contrast, alt text, labels, headings, and language: “the red items”, long capitals, images that are mostly text (on-device OCR).", "checks-crop.png"],
    ];
    cols.forEach((c, i) => {
      const x = M + i * (cw + 0.4);
      card(s, x, 1.65, cw, 5.2);
      image(s, c[2], x + 0.15, 1.8, cw - 0.3, 3.0);
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
    image(s, "draft.png", M + 0.15, 1.8, 7.1, 4.85);
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

// ---------------------------------------------------------------- 11 Engineering
{
  const s = newSlide(false, NOTES[10].notes);
  if (s) {
    kicker(s, "ENGINEERING");
    title(s, "Built to be read, tested and changed");
    const stats = [["137", "unit tests, plus 12 UI tests"], ["14", "accessibility rules, WCAG-mapped"], ["12", "architecture decision records"], ["0", "third-party dependencies, lint warnings"]];
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
      "ReportCore package (no UI imports) + app layer",
      "Swift 6 language mode, strict concurrency",
      "Documented public API; comments say why, not what",
      "Model replies are untrusted input: parsed, bounded, linted",
      "Conventional commits; both UI versions in history",
    ], M + 0.4, 4.6, cw - 0.8, 2.2, { fontSize: 14, gap: 6 });
    card(s, M + cw + 0.5, 3.95, cw, 2.9);
    text(s, "Configuration, testing, CI", M + cw + 0.9, 4.15, cw - 0.8, 0.4, { fontSize: 13, bold: true, color: C.grey });
    bullets(s, [
      "xcconfig versions and feature flags; XcodeGen project from YAML",
      "Swift Testing + XCUITest with the accessibility audit",
      "Unit tests never touch the real clipboard, network or user data",
      "GitHub Actions: tests, SwiftLint, SwiftFormat, CLI smoke test",
    ], M + cw + 0.9, 4.6, cw - 0.8, 2.2, { fontSize: 14, gap: 6 });
  }
}

// ---------------------------------------------------------------- 12 Cloud
{
  const s = newSlide(false, NOTES[11].notes);
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
    image(s, "gallery-fade.png", M + 0.12, 3.57, 6.06, 3.16);
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

// ---------------------------------------------------------------- 13 Trade-offs
{
  const s = newSlide(false, NOTES[12].notes);
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

// ---------------------------------------------------------------- 14 Close
{
  const s = newSlide(true, NOTES[13].notes);
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
