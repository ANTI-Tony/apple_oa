# 0003 Local-first, no backend for the proof of concept

Status: Accepted · Date: 2026-09-18

## Context

Enterprise status reports often contain confidential numbers. The brief asks
for a lightweight tool and mentions cloud deployment as a nice-to-have.

## Decision

Cards are stored as a JSON file in the app's sandboxed Application Support
folder. No data leaves the Mac. Image analysis uses the on-device Vision
framework. There is no login, sync or telemetry.

## Rationale

- Zero setup for reviewers and users; nothing to provision or secure.
- Privacy by default is the right posture for internal reporting.
- Import/export of JSON gives portability without a server.

## Consequences

- Sharing links and team libraries need a service. `docs/DEPLOYMENT.md`
  sketches the two candidates (CloudKit, or a small Vapor service in a
  container) and why neither is in the POC.
- Multi-device sync is a roadmap item, not a promise.
