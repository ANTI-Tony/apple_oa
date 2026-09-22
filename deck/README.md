# Presentation deck

`Reporting-Builder.pptx` is the fifteen-minute talk: 16 slides, with the full
script in the speaker notes. It opens in Keynote or PowerPoint.

The deck is generated, so the slides, the speaker notes and
[docs/PRESENTATION.md](../docs/PRESENTATION.md) cannot drift apart:

| File | Role |
|---|---|
| `notes.js` | The talk, slide by slide. The single source for the speaker notes and for `docs/PRESENTATION.md`. |
| `build.js` | Layout, written with [PptxGenJS](https://github.com/gitbrent/PptxGenJS). |
| `presentation-md.js` | Writes the script section of `docs/PRESENTATION.md` from `notes.js`. |
| `assets/` | Screenshots of the running app, captured from the app's own window with the launch overrides in `LaunchOverrides`. Nothing here is unused: `build.js` fails on a missing file. |

```sh
cd deck
npm install          # PptxGenJS, the only dependency, and only of the deck
npm run build        # writes Reporting-Builder.pptx
npm run script       # refreshes docs/PRESENTATION.md
node build.js 7      # one slide into qa/, for a quick visual check
```

The app and the `ReportCore` package have no third-party dependencies. This
folder is tooling for the talk and is not part of either.

Every image on a slide carries a real description. PptxGenJS falls back to the
file's absolute path when `altText` is missing, which leaks a local path into a
public file and is what a screen reader would read out, so `build.js` refuses to
place an image without one.

The New Card from Notes screenshot was taken with the canned model the UI tests
use (`-stubAssistant YES`): no key, no network, the same parsing and linting as
a real reply. The sheet says so in its footer.
