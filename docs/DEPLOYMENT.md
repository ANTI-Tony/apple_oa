# Deployment

Three things are deployed from this repository, all by GitHub Actions:

| What | Where | Workflow | Trigger |
|---|---|---|---|
| The macOS app, zipped with a SHA-256 checksum | GitHub Releases (and as a build artifact on manual runs) | `.github/workflows/release.yml` | tag `v*`, or manual |
| The card gallery: every template rendered as responsive, accessible HTML, plus Markdown and JSON | GitHub Pages | `.github/workflows/pages.yml` | push to `main` |
| Test, lint and project-drift checks | pull requests and `main` | `.github/workflows/ci.yml` | push to `main`, and every pull request |

The gallery is not a mock-up. It is produced by `reportcard site`, a command-line
front end to the same `ReportCore` renderers and accessibility linter the app
links. The Pages workflow lints every template with `--strict` first and refuses
to publish if one regressed.

## Why this shape

The brief asks for a choice of cloud technology. For a native Mac tool the
honest split is:

- **The app is distributed, not hosted.** CI builds and publishes it; inside an
  enterprise the same artifact flows through notarisation and MDM (below).
- **The output is what lives on the web.** Cards are HTML. Rendering them is
  pure Swift with no UI dependency, so it runs headless in CI today and could
  run in a container behind an API tomorrow without touching the renderers.
- **GitHub Actions + Pages + Releases** cost nothing, need no servers or
  secrets for the POC, and keep the whole pipeline reviewable in three YAML files.

## Local equivalents

```sh
make site         # writes ./_site, open _site/index.html
make lint-cards   # the accessibility gate the Pages workflow runs
make cli          # usage of the reportcard tool
make archive      # Release archive at build/ReportingBuilder.xcarchive

# Headless rendering of a card exported from the app (Save As → JSON Card Data)
cd Packages/ReportCore
swift run reportcard render --input ~/Desktop/card.json --format html --out card.html
swift run reportcard lint   --input ~/Desktop/card.json --strict   # exit 1 if not accessible
```

`reportcard lint` is meant for pipelines: a team can keep report cards as JSON
in a repository and fail a pull request when someone adds an image without alt
text.

## One-time repository setup

1. Push to GitHub. CI runs on its own.
2. Settings → Pages → Build and deployment → Source: **GitHub Actions**.
3. Tag a release: `git tag v0.1.0 && git push --tags`.

## Signing and enterprise distribution

Signing defaults to ad-hoc (`CODE_SIGN_IDENTITY = -`) so anyone can build and
CI needs no secrets. The app from Releases therefore opens with a Gatekeeper
warning (right-click → Open). For real distribution:

1. Add a Developer ID Application certificate and notary credentials as
   repository secrets; set `DEVELOPMENT_TEAM` in `Config/Release.xcconfig`.
2. In `release.yml`, sign during the build and notarise before packaging:
   ```sh
   xcrun notarytool submit ReportingBuilder.zip --keychain-profile "AC_NOTARY" --wait
   xcrun stapler staple ReportingBuilder.app
   ```
3. Distribute through Apple Business Manager (custom apps) or the
   organisation's MDM. Updates ride the same channel; Sparkle is the
   alternative for self-updating builds.

Runtime posture: App Sandbox on, with user-selected file access, printing, and
outgoing network connections. The network entitlement exists only for opt-in
writing assistance (ADR 0011); with that feature off, or set to the on-device
model, the app makes no network calls. A build with `FEATURE_WRITING_ASSISTANCE =
NO` removes the feature, and the entitlement can be dropped with it. Hardened
Runtime is on.

## Next step: share links and team libraries

Not built (ADR 0003). Two candidates, both reusing `ReportCore` unchanged:

| | CloudKit | Swift service in a container |
|---|---|---|
| Effort | Small: public database, one record type (card JSON + PNG asset) | Medium: Vapor, Postgres/S3, Docker, any cloud |
| Auth | Managed Apple IDs, free | Enterprise SSO (OIDC) to implement |
| Reach | Apple platforms, CloudKit JS for a web viewer | Any client |
| Fit | Fastest "share a link" for Apple-only teams | Mixed fleets, integration with existing systems |

The service variant is a thin HTTP wrapper over what the CLI already does:

```
POST /cards            body: card JSON      → { id, url }   (runs the linter, rejects inaccessible cards)
GET  /cards/{id}.html  → HTMLRenderer(.standalone)
GET  /cards/{id}.md    → MarkdownRenderer
```

## Telemetry and privacy

None. Cards, images and Vision analysis stay on the device. The one exception is
explicit: if the user enables writing assistance with a custom endpoint, the text
they submit to it goes to that endpoint. In an enterprise that endpoint must be an
approved internal gateway or the on-device model, never a public API (ADR 0011).
The gallery on Pages contains only the built-in template content.
