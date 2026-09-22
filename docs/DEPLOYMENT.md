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

### Alternatives considered for the part that is deployed

| | Chosen | Rejected, and why |
|---|---|---|
| CI | GitHub Actions | **Xcode Cloud** is the better fit inside an Apple shop: it is integrated with App Store Connect, it manages signing certificates and notarisation without a Developer ID sitting in a third-party secret store, and TestFlight covers internal testers. It needs a paid Developer Program membership, which a reviewer cloning this repository does not have, and its configuration is not a file you can read in the diff. For a POC that must build on anyone's machine, three reviewable YAML files win. |
| Static hosting | GitHub Pages | S3 + CloudFront, or an internal equivalent, is what this would be behind a corporate network. The gallery is a stateless artefact with no origin logic, so the host is a commodity decision and not worth spending the POC's budget on. What would change: the moment the gallery must be private, it needs an authenticating edge, and Pages has none. |
| Release channel | GitHub Releases | An internal artefact repository is the enterprise equivalent. Releases is where a reviewer can find a build today, which is the only requirement the POC has. |

The transferable part is not the vendor. It is `reportcard lint --strict` standing
as a required gate in front of the deploy, in `.github/workflows/pages.yml`. That
sentence survives a move to any other pipeline; the vendor names do not.

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

### Managed configuration

`AssistantSettings` reads its endpoint and model from `UserDefaults`, so an MDM
configuration profile can already supply an approved internal gateway to a
managed fleet without a rebuild — the fleet gets the endpoint, not the user.
What is *not* written is the other half: the app does not check
`objectIsForced(forKey:)`, so a profile supplies a default rather than a value a
user cannot change. That check is a few lines and it is the honest next step for
this feature inside a company (ADR 0011).

Runtime posture: App Sandbox on, with user-selected file access, printing, and
outgoing network connections. The network entitlement exists only for opt-in
writing assistance (ADR 0011); with that feature off, or set to the on-device
model, the app makes no network calls. A build with `FEATURE_WRITING_ASSISTANCE =
NO` removes the feature, and the entitlement can be dropped with it. Hardened
Runtime is on.

## If the share service had to ship

Not built, on purpose (ADR 0003): cards stay on the device, so there is no
server in the architecture to deploy. This is the design I would deploy if
sharing became a requirement, and the reasoning is specific to this codebase
rather than a stack preference.

**Keep it in Swift.** `ReportCore` declares no external dependencies and imports
only Foundation, and the renderers and the fourteen linter rules already run
headless in CI on every push. A service is therefore a thin wrapper over
exercised code rather than a rewrite. The governance argument is stronger than
the convenience one: a second implementation of those rules in another language
is a fork waiting to drift, and the rules are the product (ADR 0005). One model,
one renderer, one linter, on both sides of the network boundary.

**Deploy nothing that holds a card.** The obvious API persists cards, and the
moment it does the project owes storage, identifiers, expiry, access control and
a data-classification answer — five things a proof of concept would ship badly.
The version that costs least and contradicts ADR 0003 least is stateless:

```
POST /render   body: card JSON  → HTML or Markdown
POST /lint     body: card JSON  → the accessibility report, 422 when it fails
GET  /healthz
```

Nothing at rest, nothing to back up, nothing to classify. Card data still lives
on the device; rendering is the part that deploys.

**If sharing genuinely has to persist**, then and only then: Postgres for the
card JSON, object storage with server-side encryption for image assets, a
default retention window of 90 days on a share link, and a delete path that
removes the row and the object together. Rendered cards go to internal static
hosting behind the corporate network, never a public origin: shared status cards
carry exactly the unreleased plans and financials that ADR 0011 gives as the
reason not to send text to a public model.

**Identity is inherited, not invented.** OIDC against the organisation's
existing provider. The service keeps no user table; it validates a token, maps
group claims to visibility, and revocation happens in the directory.

### The two candidates, on an owner's axes

| | Swift service in a container | CloudKit |
|---|---|---|
| Runtime | Hummingbird on swift-nio, in an OCI image on the fleet's existing container platform. Cloud Run or App Runner for a public demo URL; Kubernetes with readiness and liveness probes for the real thing | Apple's, none of it operated here |
| Identity | Enterprise OIDC, groups from the directory | Managed Apple Accounts, provisioned through Apple Business Manager rather than the corporate directory. Sharing-based access control only: no group or role semantics |
| Data | Stateless by default. Postgres and object storage only if links must persist, in the organisation's region | Private database plus `CKShare`. Not the public database: status reports are confidential |
| Who operates it | The team that owns the tool. Structured logs, a `/metrics` endpoint, one dashboard for p99 render latency and 5xx rate | Nobody, which is the whole attraction |
| Cost | Single-digit dollars a month stateless and scale-to-zero; tens plus a managed-database bill once it persists | Within the developer account's quota at this size |
| Failure and rollback | Roll back the image tag. Stateless, so no data to restore and no migration to reverse | Apple's problem, and equally out of your hands |
| Reach | Any client | Apple platforms, plus the CloudKit Web Services REST API for a web viewer |

**Recommendation.** The containerised Swift service, because an internal tool
lives in a mixed fleet alongside systems that already exist, and CloudKit's cost is precisely the
authorization layer that an enterprise tool needs most. **What would change my
mind:** an Apple-only team that wants a share link this week and never needs to
integrate with a non-Apple system — CloudKit wins that outright, and it wins it
by not having an operator.

The cost of a service is not the invoice. It is that somebody now owns backups,
patching, migrations and a rotation, which is why this stays unbuilt until
sharing is a requirement rather than an idea.

### Deliberately not done

No deployed service, no OIDC integration, no notarisation, no container image,
no infrastructure as code. Named here so the list is a decision rather than an
omission.

## Telemetry and privacy

None. Cards, images and Vision analysis stay on the device. The one exception is
explicit: if the user enables writing assistance with a custom endpoint, the text
they submit to it goes to that endpoint. In an enterprise that endpoint must be an
approved internal gateway or the on-device model, never a public API (ADR 0011).
The gallery on Pages contains only the built-in template content.
