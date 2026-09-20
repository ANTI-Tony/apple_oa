# Presentation outline (15 minutes)

| Min | Slide | Talking points |
|---|---|---|
| 0–1 | Title | Reporting Builder: raw inputs → accessible Snippet Cards → any channel. Native macOS, Swift 6, no backend. |
| 1–2 | The user and the pain | A program manager assembles the same update for Mail, Slack and a wiki every week, re-formatting each time, and accessibility is an afterthought. |
| 2–5 | **Live demo** | Template → paste a spreadsheet range → metrics with change arrows → drop a screenshot → badge turns red → click it, jump to the block, add alt text → green → ⇧⌘C → paste into Mail → paste into Slack → share sheet. |
| 5–7 | Design principle 1: one model, many renderers | Diagram. Why the preview, PNG and email can't disagree. Tiny markup subset on purpose. |
| 7–9 | Design principle 2: accessibility as a feature | Linter rules mapped to WCAG, tested themes/templates, exported HTML semantics, VoiceOver demo (30 s). |
| 9–10 | Design principle 3: meet each channel where it is | Pasteboard representation strategy, compatibility matrix, honest "expected vs verified". |
| 10–12 | Engineering | Package/app split, Swift 6 concurrency, xcconfig flags, XcodeGen, tests at three levels, CI, ADRs. Show the CI screenshot and a test count. |
| 12–13 | Cloud and deployment | Data stays local by design; what ships to the cloud is the software and its output. Show the Pages gallery and a Release built by Actions; `reportcard lint` as a pipeline gate. Then notarisation + ABM/MDM, and CloudKit vs a Swift service for share links. |
| 13–14 | Trade-offs and limits | RTF has no alt text; PNG needs a text companion; no undo; Vision is a suggestion; what I'd do with two more weeks. |
| 14–15 | Close | Three takeaways, questions. |

## Demo checklist

- Reset: delete Application Support file or launch with `-uiTesting` from the scheme.
- Have a Numbers sheet open with a 3-column table (Metric, Current, Previous).
- Have a dashboard screenshot on the Desktop for the drop + "Extract Metrics".
- Mail compose window and Slack DM to self open behind the app.
- VoiceOver shortcut ⌘F5 ready; Reduce Motion off.
- Fallback: `docs/assets/` screenshots if a paste target misbehaves.
